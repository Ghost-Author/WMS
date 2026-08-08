package com.ruoyi.wms.service.impl;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.Objects;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.wms.domain.WmsShipment;
import com.ruoyi.wms.domain.WmsShipmentLine;
import com.ruoyi.wms.domain.WmsStock;
import com.ruoyi.wms.domain.WmsStockMovement;
import com.ruoyi.wms.mapper.WmsShipmentMapper;
import com.ruoyi.wms.mapper.WmsStockMapper;
import com.ruoyi.wms.service.IWmsShipmentService;
import com.ruoyi.wms.util.WmsDocumentNoGenerator;

@Service
public class WmsShipmentServiceImpl implements IWmsShipmentService
{
    private static final Set<String> TYPES=Set.of("SALE","RETURN","OTHER");
    private static final BigDecimal MAX_TOTAL=new BigDecimal("99999999999999.9999");
    private final WmsShipmentMapper mapper;
    private final WmsStockMapper stockMapper;
    private final WmsDocumentValidator validator;
    public WmsShipmentServiceImpl(WmsShipmentMapper mapper,WmsStockMapper stockMapper,WmsDocumentValidator validator)
    {this.mapper=mapper;this.stockMapper=stockMapper;this.validator=validator;}

    @Override public WmsShipment selectShipmentById(Long id){WmsShipment shipment=mapper.selectShipmentById(id);if(shipment!=null)shipment.setLines(mapper.selectLinesByShipmentId(id));return shipment;}
    @Override public List<WmsShipment> selectShipmentList(WmsShipment query){return mapper.selectShipmentList(query);}
    @Override @Transactional(rollbackFor=Exception.class) public int insertShipment(WmsShipment shipment)
    {
        validateHeader(shipment);validator.validateShipment(shipment.getWarehouseId(),shipment.getLines(),false);
        shipment.setStatus("DRAFT");shipment.setTotalQty(sumPlanned(shipment.getLines()));
        int rows=insertWithGeneratedNo(shipment);mapper.insertLines(shipment.getShipmentId(),shipment.getLines());return rows;
    }
    @Override @Transactional(rollbackFor=Exception.class) public int updateShipment(WmsShipment shipment)
    {
        WmsShipment old=lockDraft(shipment.getShipmentId());validateHeader(shipment);validator.validateShipment(shipment.getWarehouseId(),shipment.getLines(),false);
        shipment.setShipmentNo(old.getShipmentNo());shipment.setStatus("DRAFT");shipment.setTotalQty(sumPlanned(shipment.getLines()));
        int rows=mapper.updateShipment(shipment);if(rows!=1)throw new ServiceException("出库单状态已变更，请刷新后重试");
        mapper.deleteLinesByShipmentId(shipment.getShipmentId());mapper.insertLines(shipment.getShipmentId(),shipment.getLines());return rows;
    }
    @Override @Transactional(rollbackFor=Exception.class) public void deleteShipmentByIds(Long[] ids)
    {
        for(Long id:ids){WmsShipment shipment=lockDraft(id);mapper.deleteLinesByShipmentId(id);if(mapper.deleteShipmentById(id)!=1)throw new ServiceException("出库单【"+shipment.getShipmentNo()+"】状态已变更，不能删除");}
    }
    @Override @Transactional(rollbackFor=Exception.class) public void completeShipment(Long id,String operator)
    {
        WmsShipment shipment=lockDraft(id);List<WmsShipmentLine> lines=mapper.selectLinesByShipmentId(id);
        validator.validateShipment(shipment.getWarehouseId(),lines,true);
        lines.sort(Comparator.comparing(WmsShipmentLine::getLocationId).thenComparing(WmsShipmentLine::getItemId).thenComparing(WmsShipmentLine::getBatchNo));
        BigDecimal total=lines.stream().map(WmsShipmentLine::getShippedQty).reduce(BigDecimal.ZERO,BigDecimal::add);validateTotal(total);
        for(WmsShipmentLine line:lines)
        {
            BigDecimal qty=line.getShippedQty();
            WmsStock before=stockMapper.selectStockByKey(shipment.getWarehouseId(),line.getLocationId(),line.getItemId(),line.getBatchNo());
            validateBatchDates(line,before);
            validateSaleExpiry(shipment,before);
            int changed=stockMapper.decreaseStock(shipment.getWarehouseId(),line.getLocationId(),line.getItemId(),line.getBatchNo(),qty);
            if(changed!=1)
            {
                WmsStock current=stockMapper.selectStockByKey(shipment.getWarehouseId(),line.getLocationId(),line.getItemId(),line.getBatchNo());
                BigDecimal available=current==null?BigDecimal.ZERO:current.getAvailableQty();String item=current==null?String.valueOf(line.getItemId()):current.getItemCode();
                String location=current==null?String.valueOf(line.getLocationId()):current.getLocationCode();
                throw new ServiceException("物料【"+item+"】在库位【"+location+"】批次【"+line.getBatchNo()+"】库存不足：需要"+qty.toPlainString()+"，可用"+available.toPlainString());
            }
            WmsStock balance=stockMapper.selectStockByKey(shipment.getWarehouseId(),line.getLocationId(),line.getItemId(),line.getBatchNo());
            validateBatchDates(line,balance);
            validateSaleExpiry(shipment,balance);
            stockMapper.insertMovement(movement(shipment,line,qty.negate(),balance.getQuantity(),operator));
        }
        if(mapper.markCompleted(id,total,operator)!=1)throw new ServiceException("出库单已完成或状态已变更，请勿重复操作");
    }
    private WmsShipment lockDraft(Long id)
    {
        if(id==null)throw new ServiceException("出库单ID不能为空");WmsShipment shipment=mapper.selectShipmentForUpdate(id);
        if(shipment==null)throw new ServiceException("出库单不存在或已删除");
        if(!"DRAFT".equals(shipment.getStatus()))throw new ServiceException("出库单【"+shipment.getShipmentNo()+"】不是草稿状态，不能编辑、删除或完成");return shipment;
    }
    private int insertWithGeneratedNo(WmsShipment shipment)
    {
        for(int attempt=0;attempt<3;attempt++)
        {
            shipment.setShipmentNo(WmsDocumentNoGenerator.next("OUT"));
            try{return mapper.insertShipment(shipment);}catch(DuplicateKeyException ex){if(attempt==2)throw new ServiceException("出库单号生成冲突，请重试");}
        }
        throw new ServiceException("出库单号生成失败");
    }
    private void validateHeader(WmsShipment shipment)
    {
        if(shipment==null)throw new ServiceException("出库单不能为空");shipment.setShipmentType(StringUtils.upperCase(StringUtils.trim(shipment.getShipmentType())));
        if(!TYPES.contains(shipment.getShipmentType()))throw new ServiceException("出库类型只能为 SALE、RETURN 或 OTHER");if(shipment.getShipmentDate()==null)throw new ServiceException("出库日期不能为空");
    }
    private BigDecimal sumPlanned(List<WmsShipmentLine> lines){BigDecimal total=lines.stream().map(WmsShipmentLine::getPlannedQty).reduce(BigDecimal.ZERO,BigDecimal::add);validateTotal(total);return total;}
    private void validateTotal(BigDecimal total){if(total.compareTo(MAX_TOTAL)>0)throw new ServiceException("出库总数量超出系统可存储范围");}
    private void validateBatchDates(WmsShipmentLine line,WmsStock stock)
    {
        if(stock==null)return;
        boolean productionConflict=line.getProductionDate()!=null&&!Objects.equals(line.getProductionDate(),stock.getProductionDate());
        boolean expiryConflict=line.getExpiryDate()!=null&&!Objects.equals(line.getExpiryDate(),stock.getExpiryDate());
        if(productionConflict||expiryConflict)
            throw new ServiceException("物料【"+stock.getItemCode()+"】在库位【"+stock.getLocationCode()+"】的批次【"+line.getBatchNo()+"】生产日期或失效日期与库存不一致");
    }
    private void validateSaleExpiry(WmsShipment shipment,WmsStock stock)
    {
        if(stock==null||stock.getExpiryDate()==null||!"SALE".equals(shipment.getShipmentType()))return;
        LocalDate expiry=stock.getExpiryDate() instanceof java.sql.Date date?date.toLocalDate():stock.getExpiryDate().toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
        LocalDate shipmentDate=shipment.getShipmentDate() instanceof java.sql.Date date?date.toLocalDate():shipment.getShipmentDate().toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
        if(expiry.isBefore(shipmentDate))throw new ServiceException("物料【"+stock.getItemCode()+"】批次【"+stock.getBatchNo()+"】已过期，不能销售出库");
    }
    private WmsStockMovement movement(WmsShipment shipment,WmsShipmentLine line,BigDecimal change,BigDecimal balance,String operator)
    {
        WmsStockMovement v=new WmsStockMovement();v.setBizType("SHIPMENT");v.setBizNo(shipment.getShipmentNo());v.setWarehouseId(shipment.getWarehouseId());
        v.setLocationId(line.getLocationId());v.setItemId(line.getItemId());v.setBatchNo(line.getBatchNo());v.setChangeQty(change);v.setBalanceQty(balance);
        v.setOperator(operator);v.setRemark("出库单完成");return v;
    }
}
