package com.ruoyi.wms.service.impl;

import java.math.BigDecimal;
import java.util.List;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.wms.domain.WmsItem;
import com.ruoyi.wms.mapper.WmsItemMapper;
import com.ruoyi.wms.service.IWmsItemService;

@Service
public class WmsItemServiceImpl implements IWmsItemService
{
    private final WmsItemMapper mapper;
    public WmsItemServiceImpl(WmsItemMapper mapper){this.mapper=mapper;}
    @Override public WmsItem selectItemById(Long id){return mapper.selectItemById(id);}
    @Override public List<WmsItem> selectItemList(WmsItem query){return mapper.selectItemList(query);}
    @Override public List<WmsItem> selectEnabledOptions(){WmsItem q=new WmsItem();q.setStatus("0");return mapper.selectItemList(q);}
    @Override public int insertItem(WmsItem item){normalizeAndValidate(item);checkUnique(item);return mapper.insertItem(item);}
    @Override public int updateItem(WmsItem item){requireExists(item.getItemId());normalizeAndValidate(item);checkUnique(item);return mapper.updateItem(item);}
    @Override @Transactional(rollbackFor=Exception.class) public void deleteItemByIds(Long[] ids)
    {
        for(Long id:ids){WmsItem v=requireExists(id);if(mapper.countReferences(id)>0)throw new ServiceException("物料【"+v.getItemName()+"】已被库存或单据引用，不能删除");
            try{mapper.deleteItemById(id);}catch(DataIntegrityViolationException ex){throw new ServiceException("物料已被业务数据引用，不能删除");}}
    }
    private WmsItem requireExists(Long id){if(id==null)throw new ServiceException("物料ID不能为空");WmsItem v=mapper.selectItemById(id);if(v==null)throw new ServiceException("物料不存在或已删除");return v;}
    private void normalizeAndValidate(WmsItem v)
    {
        v.setItemCode(v.getItemCode().trim());v.setItemName(v.getItemName().trim());v.setUnit(v.getUnit().trim());v.setBarcode(StringUtils.trimToNull(v.getBarcode()));
        if(v.getMinStock()==null)v.setMinStock(BigDecimal.ZERO);if(v.getMaxStock()==null)v.setMaxStock(BigDecimal.ZERO);if(StringUtils.isBlank(v.getStatus()))v.setStatus("0");
        if(v.getMinStock().signum()<0||v.getMaxStock().signum()<0)throw new ServiceException("库存上下限不能小于0");
        if(v.getMaxStock().signum()>0&&v.getMinStock().compareTo(v.getMaxStock())>0)throw new ServiceException("最低库存不能大于最高库存");
        if(!"0".equals(v.getStatus())&&!"1".equals(v.getStatus()))throw new ServiceException("物料状态只能为0或1");
    }
    private void checkUnique(WmsItem v)
    {
        if(mapper.countCode(v.getItemCode(),v.getItemId())>0)throw new ServiceException("物料编码已存在");
        if(StringUtils.isNotBlank(v.getBarcode())&&mapper.countBarcode(v.getBarcode(),v.getItemId())>0)throw new ServiceException("物料条码已存在");
    }
}
