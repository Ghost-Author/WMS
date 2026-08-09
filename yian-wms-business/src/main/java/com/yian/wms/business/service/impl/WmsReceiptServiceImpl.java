package com.yian.wms.business.service.impl;

import java.math.BigDecimal;
import java.util.Comparator;
import java.util.Objects;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.transaction.annotation.Transactional;
import com.yian.wms.common.exception.ServiceException;
import com.yian.wms.common.utils.StringUtils;
import com.yian.wms.business.domain.WmsReceipt;
import com.yian.wms.business.domain.WmsReceiptLine;
import com.yian.wms.business.domain.WmsStock;
import com.yian.wms.business.domain.WmsStockMovement;
import com.yian.wms.business.mapper.WmsReceiptMapper;
import com.yian.wms.business.mapper.WmsStockMapper;
import com.yian.wms.business.service.IWmsReceiptService;
import com.yian.wms.business.util.WmsDocumentNoGenerator;

@Service
public class WmsReceiptServiceImpl implements IWmsReceiptService
{
    private static final Set<String> TYPES=Set.of("PURCHASE","RETURN","OTHER");
    private static final BigDecimal MAX_TOTAL=new BigDecimal("99999999999999.9999");
    private final WmsReceiptMapper mapper;
    private final WmsStockMapper stockMapper;
    private final WmsDocumentValidator validator;
    public WmsReceiptServiceImpl(WmsReceiptMapper mapper,WmsStockMapper stockMapper,WmsDocumentValidator validator)
    {this.mapper=mapper;this.stockMapper=stockMapper;this.validator=validator;}

    @Override public WmsReceipt selectReceiptById(Long id)
    {
        WmsReceipt receipt=mapper.selectReceiptById(id);if(receipt!=null)receipt.setLines(mapper.selectLinesByReceiptId(id));return receipt;
    }
    @Override public List<WmsReceipt> selectReceiptList(WmsReceipt query){return mapper.selectReceiptList(query);}

    @Override @Transactional(rollbackFor=Exception.class)
    public int insertReceipt(WmsReceipt receipt)
    {
        validateHeader(receipt);validator.validateReceipt(receipt.getWarehouseId(),receipt.getLines(),false);
        receipt.setStatus("DRAFT");receipt.setTotalQty(sumPlanned(receipt.getLines()));
        int rows=insertWithGeneratedNo(receipt);mapper.insertLines(receipt.getReceiptId(),receipt.getLines());return rows;
    }

    @Override @Transactional(rollbackFor=Exception.class)
    public int updateReceipt(WmsReceipt receipt)
    {
        WmsReceipt old=lockDraft(receipt.getReceiptId());validateHeader(receipt);validator.validateReceipt(receipt.getWarehouseId(),receipt.getLines(),false);
        receipt.setReceiptNo(old.getReceiptNo());receipt.setStatus("DRAFT");receipt.setTotalQty(sumPlanned(receipt.getLines()));
        int rows=mapper.updateReceipt(receipt);if(rows!=1)throw new ServiceException("入库单状态已变更，请刷新后重试");
        mapper.deleteLinesByReceiptId(receipt.getReceiptId());mapper.insertLines(receipt.getReceiptId(),receipt.getLines());return rows;
    }

    @Override @Transactional(rollbackFor=Exception.class)
    public void deleteReceiptByIds(Long[] ids)
    {
        for(Long id:ids){WmsReceipt receipt=lockDraft(id);mapper.deleteLinesByReceiptId(id);if(mapper.deleteReceiptById(id)!=1)throw new ServiceException("入库单【"+receipt.getReceiptNo()+"】状态已变更，不能删除");}
    }

    @Override @Transactional(rollbackFor=Exception.class)
    public void completeReceipt(Long id,String operator)
    {
        WmsReceipt receipt=lockDraft(id);List<WmsReceiptLine> lines=mapper.selectLinesByReceiptId(id);
        validator.validateReceipt(receipt.getWarehouseId(),lines,true);
        lines.sort(Comparator.comparing(WmsReceiptLine::getLocationId).thenComparing(WmsReceiptLine::getItemId).thenComparing(WmsReceiptLine::getBatchNo));
        BigDecimal total=lines.stream().map(WmsReceiptLine::getReceivedQty).reduce(BigDecimal.ZERO,BigDecimal::add);validateTotal(total);
        for(WmsReceiptLine line:lines)
        {
            BigDecimal qty=line.getReceivedQty();
            WmsStock stock=new WmsStock();stock.setWarehouseId(receipt.getWarehouseId());stock.setLocationId(line.getLocationId());
            stock.setItemId(line.getItemId());stock.setBatchNo(line.getBatchNo());stock.setProductionDate(line.getProductionDate());
            stock.setExpiryDate(line.getExpiryDate());stock.setQuantity(qty);stockMapper.upsertStock(stock);
            WmsStock balance=stockMapper.selectStockByKey(receipt.getWarehouseId(),line.getLocationId(),line.getItemId(),line.getBatchNo());
            if(balance==null)throw new ServiceException("入库库存更新失败");
            validateBatchDates(line,balance);
            stockMapper.insertMovement(movement("RECEIPT",receipt.getReceiptNo(),receipt.getWarehouseId(),line.getLocationId(),line.getItemId(),line.getBatchNo(),qty,balance.getQuantity(),operator));
        }
        if(mapper.markCompleted(id,total,operator)!=1)throw new ServiceException("入库单已完成或状态已变更，请勿重复操作");
    }

    private WmsReceipt lockDraft(Long id)
    {
        if(id==null)throw new ServiceException("入库单ID不能为空");WmsReceipt receipt=mapper.selectReceiptForUpdate(id);
        if(receipt==null)throw new ServiceException("入库单不存在或已删除");
        if(!"DRAFT".equals(receipt.getStatus()))throw new ServiceException("入库单【"+receipt.getReceiptNo()+"】不是草稿状态，不能编辑、删除或完成");return receipt;
    }
    private int insertWithGeneratedNo(WmsReceipt receipt)
    {
        for(int attempt=0;attempt<3;attempt++)
        {
            receipt.setReceiptNo(WmsDocumentNoGenerator.next("IN"));
            try{return mapper.insertReceipt(receipt);}catch(DuplicateKeyException ex){if(attempt==2)throw new ServiceException("入库单号生成冲突，请重试");}
        }
        throw new ServiceException("入库单号生成失败");
    }
    private void validateHeader(WmsReceipt receipt)
    {
        if(receipt==null)throw new ServiceException("入库单不能为空");
        receipt.setReceiptType(StringUtils.upperCase(StringUtils.trim(receipt.getReceiptType())));
        if(!TYPES.contains(receipt.getReceiptType()))throw new ServiceException("入库类型只能为 PURCHASE、RETURN 或 OTHER");
        if(receipt.getReceiptDate()==null)throw new ServiceException("入库日期不能为空");
    }
    private BigDecimal sumPlanned(List<WmsReceiptLine> lines){BigDecimal total=lines.stream().map(WmsReceiptLine::getPlannedQty).reduce(BigDecimal.ZERO,BigDecimal::add);validateTotal(total);return total;}
    private void validateTotal(BigDecimal total){if(total.compareTo(MAX_TOTAL)>0)throw new ServiceException("入库总数量超出系统可存储范围");}
    private void validateBatchDates(WmsReceiptLine line,WmsStock stock)
    {
        boolean productionConflict=line.getProductionDate()!=null&&!Objects.equals(line.getProductionDate(),stock.getProductionDate());
        boolean expiryConflict=line.getExpiryDate()!=null&&!Objects.equals(line.getExpiryDate(),stock.getExpiryDate());
        if(productionConflict||expiryConflict)
            throw new ServiceException("物料【"+stock.getItemCode()+"】在库位【"+stock.getLocationCode()+"】的批次【"+line.getBatchNo()+"】已存在，生产日期或失效日期与现有库存不一致");
    }
    private WmsStockMovement movement(String type,String no,Long warehouseId,Long locationId,Long itemId,String batchNo,BigDecimal change,BigDecimal balance,String operator)
    {
        WmsStockMovement value=new WmsStockMovement();value.setBizType(type);value.setBizNo(no);value.setWarehouseId(warehouseId);value.setLocationId(locationId);
        value.setItemId(itemId);value.setBatchNo(batchNo);value.setChangeQty(change);value.setBalanceQty(balance);value.setOperator(operator);value.setRemark("入库单完成");return value;
    }
}
