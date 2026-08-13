package com.yian.wms.business.service.impl;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.yian.wms.business.domain.WmsArea;
import com.yian.wms.business.domain.WmsLocation;
import com.yian.wms.business.domain.WmsStock;
import com.yian.wms.business.domain.WmsStockMovement;
import com.yian.wms.business.domain.WmsWarehouse;
import com.yian.wms.business.domain.dto.WmsStockAdjustRequest;
import com.yian.wms.business.domain.dto.WmsStockTransferRequest;
import com.yian.wms.business.mapper.WmsAreaMapper;
import com.yian.wms.business.mapper.WmsLocationMapper;
import com.yian.wms.business.mapper.WmsStockMapper;
import com.yian.wms.business.mapper.WmsWarehouseMapper;
import com.yian.wms.business.service.IWmsStockService;
import com.yian.wms.business.util.WmsDocumentNoGenerator;
import com.yian.wms.common.exception.ServiceException;

@Service
public class WmsStockServiceImpl implements IWmsStockService
{
    private static final BigDecimal MAX_QUANTITY = new BigDecimal("99999999999999.9999");
    private static final Comparator<StockKey> STOCK_KEY_COMPARATOR = Comparator
            .comparing(StockKey::warehouseId)
            .thenComparing(StockKey::locationId)
            .thenComparing(StockKey::itemId)
            .thenComparing(StockKey::batchNo);

    private final WmsStockMapper mapper;
    private final WmsWarehouseMapper warehouseMapper;
    private final WmsAreaMapper areaMapper;
    private final WmsLocationMapper locationMapper;

    public WmsStockServiceImpl(WmsStockMapper mapper, WmsWarehouseMapper warehouseMapper,
            WmsAreaMapper areaMapper, WmsLocationMapper locationMapper)
    {
        this.mapper = mapper;
        this.warehouseMapper = warehouseMapper;
        this.areaMapper = areaMapper;
        this.locationMapper = locationMapper;
    }

    @Override
    public List<WmsStock> selectStockList(WmsStock query) { return mapper.selectStockList(query); }

    @Override
    public List<WmsStock> selectLowStockList(WmsStock query) { return mapper.selectLowStockList(query); }

    @Override
    public List<WmsStockMovement> selectMovementList(WmsStockMovement query) { return mapper.selectMovementList(query); }

    @Override
    // Capacity writers serialize on the location row; READ_COMMITTED makes the following SUM see the prior writer's commit.
    @Transactional(isolation = Isolation.READ_COMMITTED, rollbackFor = Exception.class)
    public String transferStock(WmsStockTransferRequest request, String operator)
    {
        validateTransferRequest(request);
        WmsStock snapshot = mapper.selectStockById(request.getStockId());
        if (snapshot == null)
        {
            throw new ServiceException("来源库存不存在或已删除，请刷新库存列表后重试");
        }
        if (Objects.equals(snapshot.getLocationId(), request.getTargetLocationId()))
        {
            throw new ServiceException("目标库位不能与来源库位相同");
        }

        Map<Long, WmsLocation> lockedLocations = lockLocations(snapshot.getLocationId(), request.getTargetLocationId());
        WmsLocation sourceLocation = validateEnabledLocation(lockedLocations.get(snapshot.getLocationId()),
                snapshot.getWarehouseId(), "来源", true);
        WmsLocation targetLocation = validateEnabledLocation(lockedLocations.get(request.getTargetLocationId()),
                null, "目标", true);
        String batchNo = snapshot.getBatchNo() == null ? "" : snapshot.getBatchNo();
        StockKey sourceKey = new StockKey(snapshot.getWarehouseId(), snapshot.getLocationId(), snapshot.getItemId(), batchNo);
        StockKey targetKey = new StockKey(targetLocation.getWarehouseId(), targetLocation.getLocationId(), snapshot.getItemId(), batchNo);

        boolean sourceFirst = STOCK_KEY_COMPARATOR.compare(sourceKey, targetKey) < 0;
        WmsStock first = lockStock(sourceFirst ? sourceKey : targetKey);
        WmsStock second = lockStock(sourceFirst ? targetKey : sourceKey);
        WmsStock source = sourceFirst ? first : second;
        WmsStock target = sourceFirst ? second : first;
        if (source == null || !Objects.equals(source.getStockId(), request.getStockId()))
        {
            throw new ServiceException("来源库存已发生变化，请刷新库存列表后重试");
        }

        validateStockBalance(source, "来源");
        BigDecimal quantity = request.getQuantity();
        BigDecimal available = source.getQuantity().subtract(source.getLockedQuantity());
        if (available.compareTo(quantity) < 0)
        {
            throw new ServiceException("物料ID【" + source.getItemId() + "】在来源库位【" + sourceLocation.getLocationCode()
                    + "】批次【" + displayBatch(batchNo) + "】可用库存不足：需要" + quantity.toPlainString()
                    + "，可用" + available.toPlainString());
        }
        if (target != null)
        {
            validateStockBalance(target, "目标");
            validateBatchDates(source, target, targetLocation);
        }
        BigDecimal targetBalance = (target == null ? BigDecimal.ZERO : target.getQuantity()).add(quantity);
        if (targetBalance.compareTo(MAX_QUANTITY) > 0)
        {
            throw new ServiceException("目标库位【" + targetLocation.getLocationCode() + "】调拨后的库存数量超出系统可存储范围");
        }
        validateLocationCapacity(targetLocation, quantity);

        if (mapper.decreaseStockById(source.getStockId(), quantity) != 1)
        {
            throw new ServiceException("来源库存扣减失败，库存可能已被其他业务占用，请刷新后重试");
        }
        WmsStock addition = new WmsStock();
        addition.setWarehouseId(targetLocation.getWarehouseId());
        addition.setLocationId(targetLocation.getLocationId());
        addition.setItemId(source.getItemId());
        addition.setBatchNo(batchNo);
        addition.setProductionDate(source.getProductionDate());
        addition.setExpiryDate(source.getExpiryDate());
        addition.setQuantity(quantity);
        if (mapper.upsertStock(addition) < 1)
        {
            throw new ServiceException("目标库存增加失败，请稍后重试");
        }

        String transferNo = WmsDocumentNoGenerator.next("TR");
        String remark = request.getRemark().trim();
        BigDecimal sourceBalance = source.getQuantity().subtract(quantity);
        int outRows = mapper.insertMovement(movement("TRANSFER_OUT", transferNo, source.getWarehouseId(), source.getLocationId(),
                source.getItemId(), batchNo, quantity.negate(), sourceBalance, operator, remark));
        int inRows = mapper.insertMovement(movement("TRANSFER_IN", transferNo, targetLocation.getWarehouseId(), targetLocation.getLocationId(),
                source.getItemId(), batchNo, quantity, targetBalance, operator, remark));
        if (outRows != 1 || inRows != 1)
        {
            throw new ServiceException("库存调拨流水记录失败，本次调拨已回滚，请重试");
        }
        return transferNo;
    }

    @Override
    // Capacity writers serialize on the location row; READ_COMMITTED makes the following SUM see the prior writer's commit.
    @Transactional(isolation = Isolation.READ_COMMITTED, rollbackFor = Exception.class)
    public String adjustStock(WmsStockAdjustRequest request, String operator)
    {
        validateAdjustRequest(request);
        WmsStock snapshot = mapper.selectStockById(request.getStockId());
        if (snapshot == null)
        {
            throw new ServiceException("待盘点库存不存在或已删除，请刷新库存列表后重试");
        }
        WmsLocation location = validateEnabledLocation(locationMapper.selectLocationByIdForUpdate(snapshot.getLocationId()),
                snapshot.getWarehouseId(), "盘点", false);
        WmsStock stock = mapper.selectStockByIdForUpdate(request.getStockId());
        if (stock == null || !Objects.equals(stock.getLocationId(), snapshot.getLocationId()))
        {
            throw new ServiceException("待盘点库存已发生变化，请刷新库存列表后重试");
        }
        validateStockBalance(stock, "盘点");

        BigDecimal counted = request.getCountedQuantity();
        if (counted.compareTo(stock.getLockedQuantity()) < 0)
        {
            throw new ServiceException("实盘数量不能小于锁定数量：锁定" + stock.getLockedQuantity().toPlainString()
                    + "，实盘" + counted.toPlainString());
        }
        BigDecimal difference = counted.subtract(stock.getQuantity());
        if (difference.signum() == 0)
        {
            throw new ServiceException("实盘数量与账面数量一致，无需调整库存");
        }
        if (difference.signum() > 0)
        {
            validateLocationCapacity(location, difference);
        }
        if (mapper.updateStockQuantity(stock.getStockId(), counted) != 1)
        {
            throw new ServiceException("盘点库存调整失败，库存可能已被其他业务占用，请刷新后重试");
        }

        String adjustmentNo = WmsDocumentNoGenerator.next("ADJ");
        String type = difference.signum() > 0 ? "ADJUST_IN" : "ADJUST_OUT";
        int movementRows = mapper.insertMovement(movement(type, adjustmentNo, stock.getWarehouseId(), stock.getLocationId(), stock.getItemId(),
                stock.getBatchNo() == null ? "" : stock.getBatchNo(), difference, counted, operator, request.getRemark().trim()));
        if (movementRows != 1)
        {
            throw new ServiceException("库存盘点流水记录失败，本次调整已回滚，请重试");
        }
        return adjustmentNo;
    }

    private WmsStock lockStock(StockKey key)
    {
        return mapper.selectStockByKeyForUpdate(key.warehouseId(), key.locationId(), key.itemId(), key.batchNo());
    }

    private Map<Long, WmsLocation> lockLocations(Long firstLocationId, Long secondLocationId)
    {
        List<Long> ids = new ArrayList<>();
        ids.add(firstLocationId);
        if (!Objects.equals(firstLocationId, secondLocationId))
        {
            ids.add(secondLocationId);
        }
        ids.sort(Long::compareTo);
        Map<Long, WmsLocation> locations = new LinkedHashMap<>();
        for (Long id : ids)
        {
            locations.put(id, locationMapper.selectLocationByIdForUpdate(id));
        }
        return locations;
    }

    private WmsLocation validateEnabledLocation(WmsLocation location, Long expectedWarehouseId, String role,
            boolean movable)
    {
        if (location == null)
        {
            throw new ServiceException(role + "库位不存在或已删除");
        }
        if (!"0".equals(location.getStatus()))
        {
            throw new ServiceException(role + "库位【" + location.getLocationCode() + "】已停用");
        }
        if (expectedWarehouseId != null && !Objects.equals(expectedWarehouseId, location.getWarehouseId()))
        {
            throw new ServiceException(role + "库存的仓库与库位归属不一致，请联系管理员检查基础数据");
        }

        WmsWarehouse warehouse = warehouseMapper.selectWarehouseById(location.getWarehouseId());
        if (warehouse == null)
        {
            throw new ServiceException(role + "库位所属仓库不存在或已删除");
        }
        if (!"0".equals(warehouse.getStatus()))
        {
            throw new ServiceException(role + "库位所属仓库【" + warehouse.getWarehouseName() + "】已停用");
        }
        WmsArea area = areaMapper.selectAreaById(location.getAreaId());
        if (area == null)
        {
            throw new ServiceException(role + "库位所属库区不存在或已删除");
        }
        if (!Objects.equals(area.getWarehouseId(), location.getWarehouseId()))
        {
            throw new ServiceException(role + "库位与库区的仓库归属不一致，请联系管理员检查基础数据");
        }
        if (!"0".equals(area.getStatus()))
        {
            throw new ServiceException(role + "库位所属库区【" + area.getAreaName() + "】已停用");
        }
        if (movable && "DEFECTIVE".equals(location.getLocationType()))
        {
            throw new ServiceException(role + "库位【" + location.getLocationCode() + "】为不良品库位，不能执行直接调拨");
        }
        return location;
    }

    private void validateLocationCapacity(WmsLocation location, BigDecimal increase)
    {
        BigDecimal capacity = location.getCapacityQty();
        if (capacity == null || capacity.signum() == 0)
        {
            return;
        }
        BigDecimal current = mapper.selectTotalQuantityByLocation(location.getLocationId());
        if (current == null)
        {
            current = BigDecimal.ZERO;
        }
        BigDecimal after = current.add(increase);
        if (after.compareTo(capacity) > 0)
        {
            throw new ServiceException("库位【" + location.getLocationCode() + "】容量不足：容量" + capacity.toPlainString()
                    + "，当前" + current.toPlainString() + "，本次增加" + increase.toPlainString());
        }
    }

    private void validateTransferRequest(WmsStockTransferRequest request)
    {
        if (request == null)
        {
            throw new ServiceException("库存调拨请求不能为空");
        }
        validatePositiveId(request.getStockId(), "来源库存ID");
        validatePositiveId(request.getTargetLocationId(), "目标库位ID");
        validateQuantity(request.getQuantity(), true, "调拨数量");
        validateRemark(request.getRemark(), "调拨原因");
    }

    private void validateAdjustRequest(WmsStockAdjustRequest request)
    {
        if (request == null)
        {
            throw new ServiceException("库存盘点请求不能为空");
        }
        validatePositiveId(request.getStockId(), "库存ID");
        validateQuantity(request.getCountedQuantity(), false, "实盘数量");
        validateRemark(request.getRemark(), "盘点说明");
    }

    private void validatePositiveId(Long id, String field)
    {
        if (id == null || id <= 0)
        {
            throw new ServiceException(field + "必须大于0");
        }
    }

    private void validateQuantity(BigDecimal quantity, boolean positive, String field)
    {
        if (quantity == null)
        {
            throw new ServiceException(field + "不能为空");
        }
        if (positive ? quantity.signum() <= 0 : quantity.signum() < 0)
        {
            throw new ServiceException(positive ? field + "必须大于0" : field + "不能小于0");
        }
        if (quantity.compareTo(MAX_QUANTITY) > 0)
        {
            throw new ServiceException(field + "超出系统可存储范围");
        }
        if (quantity.stripTrailingZeros().scale() > 4)
        {
            throw new ServiceException(field + "最多保留4位小数");
        }
    }

    private void validateRemark(String remark, String field)
    {
        if (remark == null || remark.trim().isEmpty())
        {
            throw new ServiceException(field + "不能为空");
        }
        if (remark.trim().length() > 500)
        {
            throw new ServiceException(field + "不能超过500个字符");
        }
    }

    private void validateStockBalance(WmsStock stock, String role)
    {
        if (stock.getQuantity() == null || stock.getLockedQuantity() == null
                || stock.getQuantity().signum() < 0 || stock.getLockedQuantity().signum() < 0
                || stock.getLockedQuantity().compareTo(stock.getQuantity()) > 0)
        {
            throw new ServiceException(role + "库存数量或锁定数量异常，请联系管理员检查库存数据");
        }
    }

    private void validateBatchDates(WmsStock source, WmsStock target, WmsLocation targetLocation)
    {
        if (!sameDate(source.getProductionDate(), target.getProductionDate())
                || !sameDate(source.getExpiryDate(), target.getExpiryDate()))
        {
            throw new ServiceException("目标库位【" + targetLocation.getLocationCode() + "】已存在物料ID【" + source.getItemId()
                    + "】批次【" + displayBatch(source.getBatchNo()) + "】，但生产日期或失效日期与来源库存不一致");
        }
    }

    private boolean sameDate(Date first, Date second)
    {
        return first == null ? second == null : second != null && first.getTime() == second.getTime();
    }

    private String displayBatch(String batchNo)
    {
        return batchNo == null || batchNo.isEmpty() ? "无批次" : batchNo;
    }

    private WmsStockMovement movement(String type, String no, Long warehouseId, Long locationId, Long itemId,
            String batchNo, BigDecimal change, BigDecimal balance, String operator, String remark)
    {
        WmsStockMovement movement = new WmsStockMovement();
        movement.setBizType(type);
        movement.setBizNo(no);
        movement.setWarehouseId(warehouseId);
        movement.setLocationId(locationId);
        movement.setItemId(itemId);
        movement.setBatchNo(batchNo);
        movement.setChangeQty(change);
        movement.setBalanceQty(balance);
        movement.setOperator(operator);
        movement.setRemark(remark);
        return movement;
    }

    private record StockKey(Long warehouseId, Long locationId, Long itemId, String batchNo) { }
}
