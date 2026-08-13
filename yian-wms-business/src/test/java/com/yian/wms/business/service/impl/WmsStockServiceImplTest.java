package com.yian.wms.business.service.impl;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
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
import com.yian.wms.common.exception.ServiceException;

@ExtendWith(MockitoExtension.class)
class WmsStockServiceImplTest
{
    @Mock private WmsStockMapper stockMapper;
    @Mock private WmsWarehouseMapper warehouseMapper;
    @Mock private WmsAreaMapper areaMapper;
    @Mock private WmsLocationMapper locationMapper;

    private WmsStockServiceImpl service;

    @BeforeEach
    void setUp()
    {
        service = new WmsStockServiceImpl(stockMapper, warehouseMapper, areaMapper, locationMapper);
    }

    @Test
    void transferStockMovesQuantityAndCreatesPairedMovements()
    {
        WmsStock source = stock(100L, 1L, 10L, 7L, "B-001", "10", "2");
        when(stockMapper.selectStockById(100L)).thenReturn(source);
        stubEnabledLocation(10L, 1L, 101L, "A-01-01");
        stubEnabledLocation(20L, 1L, 101L, "A-01-02");
        stubEnabledWarehouseAndArea(1L, 101L);
        when(stockMapper.selectStockByKeyForUpdate(1L, 10L, 7L, "B-001")).thenReturn(source);
        when(stockMapper.selectStockByKeyForUpdate(1L, 20L, 7L, "B-001")).thenReturn(null);
        when(stockMapper.decreaseStockById(100L, new BigDecimal("3"))).thenReturn(1);
        when(stockMapper.upsertStock(any(WmsStock.class))).thenReturn(1);
        when(stockMapper.insertMovement(any(WmsStockMovement.class))).thenReturn(1);

        String transferNo = service.transferStock(transferRequest(100L, 20L, "3"), "tester");

        assertTrue(transferNo.startsWith("TR"));
        verify(stockMapper).decreaseStockById(100L, new BigDecimal("3"));
        ArgumentCaptor<WmsStock> targetStock = ArgumentCaptor.forClass(WmsStock.class);
        verify(stockMapper).upsertStock(targetStock.capture());
        assertEquals(1L, targetStock.getValue().getWarehouseId());
        assertEquals(20L, targetStock.getValue().getLocationId());
        assertEquals(7L, targetStock.getValue().getItemId());
        assertEquals(new BigDecimal("3"), targetStock.getValue().getQuantity());

        ArgumentCaptor<WmsStockMovement> movements = ArgumentCaptor.forClass(WmsStockMovement.class);
        verify(stockMapper, org.mockito.Mockito.times(2)).insertMovement(movements.capture());
        List<WmsStockMovement> values = movements.getAllValues();
        assertEquals("TRANSFER_OUT", values.get(0).getBizType());
        assertEquals(new BigDecimal("-3"), values.get(0).getChangeQty());
        assertEquals(new BigDecimal("7"), values.get(0).getBalanceQty());
        assertEquals("TRANSFER_IN", values.get(1).getBizType());
        assertEquals(new BigDecimal("3"), values.get(1).getChangeQty());
        assertEquals(new BigDecimal("3"), values.get(1).getBalanceQty());
        assertEquals(transferNo, values.get(0).getBizNo());
        assertEquals(transferNo, values.get(1).getBizNo());
    }

    @Test
    void transferStockRejectsQuantityAboveAvailableBalanceWithoutWriting()
    {
        WmsStock source = stock(100L, 1L, 10L, 7L, "B-001", "10", "8");
        when(stockMapper.selectStockById(100L)).thenReturn(source);
        stubEnabledLocation(10L, 1L, 101L, "A-01-01");
        stubEnabledLocation(20L, 1L, 101L, "A-01-02");
        stubEnabledWarehouseAndArea(1L, 101L);
        when(stockMapper.selectStockByKeyForUpdate(1L, 10L, 7L, "B-001")).thenReturn(source);
        when(stockMapper.selectStockByKeyForUpdate(1L, 20L, 7L, "B-001")).thenReturn(null);

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.transferStock(transferRequest(100L, 20L, "3"), "tester"));

        assertTrue(error.getMessage().contains("可用库存不足"));
        verify(stockMapper, never()).decreaseStockById(any(), any());
        verify(stockMapper, never()).upsertStock(any());
        verify(stockMapper, never()).insertMovement(any());
    }

    @Test
    void transferStockRejectsTargetLocationCapacityOverflowWithoutWriting()
    {
        WmsStock source = stock(100L, 1L, 10L, 7L, "B-001", "10", "2");
        when(stockMapper.selectStockById(100L)).thenReturn(source);
        stubEnabledLocation(10L, 1L, 101L, "A-01-01", "1000");
        stubEnabledLocation(20L, 1L, 101L, "A-01-02", "5");
        stubEnabledWarehouseAndArea(1L, 101L);
        when(stockMapper.selectStockByKeyForUpdate(1L, 10L, 7L, "B-001")).thenReturn(source);
        when(stockMapper.selectStockByKeyForUpdate(1L, 20L, 7L, "B-001")).thenReturn(null);
        when(stockMapper.selectTotalQuantityByLocation(20L)).thenReturn(new BigDecimal("4"));

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.transferStock(transferRequest(100L, 20L, "2"), "tester"));

        assertTrue(error.getMessage().contains("容量不足"));
        verify(stockMapper, never()).decreaseStockById(any(), any());
        verify(stockMapper, never()).upsertStock(any());
        verify(stockMapper, never()).insertMovement(any());
    }

    @Test
    void adjustStockUpdatesCountedBalanceAndCreatesOutboundMovement()
    {
        WmsStock stock = stock(100L, 1L, 10L, 7L, "B-001", "10", "2");
        when(stockMapper.selectStockById(100L)).thenReturn(stock);
        when(stockMapper.selectStockByIdForUpdate(100L)).thenReturn(stock);
        stubEnabledLocation(10L, 1L, 101L, "A-01-01");
        stubEnabledWarehouseAndArea(1L, 101L);
        when(stockMapper.updateStockQuantity(100L, new BigDecimal("7"))).thenReturn(1);
        when(stockMapper.insertMovement(any(WmsStockMovement.class))).thenReturn(1);

        String adjustmentNo = service.adjustStock(adjustRequest(100L, "7"), "counter");

        assertTrue(adjustmentNo.startsWith("ADJ"));
        verify(stockMapper).updateStockQuantity(100L, new BigDecimal("7"));
        ArgumentCaptor<WmsStockMovement> movement = ArgumentCaptor.forClass(WmsStockMovement.class);
        verify(stockMapper).insertMovement(movement.capture());
        assertEquals("ADJUST_OUT", movement.getValue().getBizType());
        assertEquals(new BigDecimal("-3"), movement.getValue().getChangeQty());
        assertEquals(new BigDecimal("7"), movement.getValue().getBalanceQty());
        assertEquals(adjustmentNo, movement.getValue().getBizNo());
        assertEquals("counter", movement.getValue().getOperator());
    }

    @Test
    void adjustStockRejectsCountBelowLockedQuantityWithoutWriting()
    {
        WmsStock stock = stock(100L, 1L, 10L, 7L, "B-001", "10", "4");
        when(stockMapper.selectStockById(100L)).thenReturn(stock);
        when(stockMapper.selectStockByIdForUpdate(100L)).thenReturn(stock);
        stubEnabledLocation(10L, 1L, 101L, "A-01-01");
        stubEnabledWarehouseAndArea(1L, 101L);

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.adjustStock(adjustRequest(100L, "3"), "counter"));

        assertTrue(error.getMessage().contains("不能小于锁定数量"));
        verify(stockMapper, never()).updateStockQuantity(any(), any());
        verify(stockMapper, never()).insertMovement(any());
    }

    @Test
    void adjustStockRejectsLocationCapacityOverflowWithoutWriting()
    {
        WmsStock stock = stock(100L, 1L, 10L, 7L, "B-001", "10", "2");
        when(stockMapper.selectStockById(100L)).thenReturn(stock);
        when(stockMapper.selectStockByIdForUpdate(100L)).thenReturn(stock);
        stubEnabledLocation(10L, 1L, 101L, "A-01-01", "11");
        stubEnabledWarehouseAndArea(1L, 101L);
        when(stockMapper.selectTotalQuantityByLocation(10L)).thenReturn(new BigDecimal("10"));

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.adjustStock(adjustRequest(100L, "12"), "counter"));

        assertTrue(error.getMessage().contains("容量不足"));
        verify(stockMapper, never()).updateStockQuantity(any(), any());
        verify(stockMapper, never()).insertMovement(any());
    }

    @Test
    void adjustStockRejectsUnchangedCountWithoutWriting()
    {
        WmsStock stock = stock(100L, 1L, 10L, 7L, "B-001", "10", "2");
        when(stockMapper.selectStockById(100L)).thenReturn(stock);
        when(stockMapper.selectStockByIdForUpdate(100L)).thenReturn(stock);
        stubEnabledLocation(10L, 1L, 101L, "A-01-01");
        stubEnabledWarehouseAndArea(1L, 101L);

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.adjustStock(adjustRequest(100L, "10"), "counter"));

        assertTrue(error.getMessage().contains("无需调整库存"));
        verify(stockMapper, never()).updateStockQuantity(any(), any());
        verify(stockMapper, never()).insertMovement(any());
    }

    private void stubEnabledLocation(Long locationId, Long warehouseId, Long areaId, String code)
    {
        stubEnabledLocation(locationId, warehouseId, areaId, code, "1000");
    }

    private void stubEnabledLocation(Long locationId, Long warehouseId, Long areaId, String code, String capacity)
    {
        WmsLocation location = new WmsLocation();
        location.setLocationId(locationId);
        location.setWarehouseId(warehouseId);
        location.setAreaId(areaId);
        location.setLocationCode(code);
        location.setLocationType("STORAGE");
        location.setCapacityQty(new BigDecimal(capacity));
        location.setStatus("0");
        when(locationMapper.selectLocationByIdForUpdate(locationId)).thenReturn(location);
    }

    private void stubEnabledWarehouseAndArea(Long warehouseId, Long areaId)
    {
        WmsWarehouse warehouse = new WmsWarehouse();
        warehouse.setWarehouseId(warehouseId);
        warehouse.setWarehouseName("测试仓");
        warehouse.setStatus("0");
        when(warehouseMapper.selectWarehouseById(warehouseId)).thenReturn(warehouse);

        WmsArea area = new WmsArea();
        area.setAreaId(areaId);
        area.setWarehouseId(warehouseId);
        area.setAreaName("存储区");
        area.setAreaType("STORAGE");
        area.setStatus("0");
        when(areaMapper.selectAreaById(areaId)).thenReturn(area);
    }

    private WmsStock stock(Long stockId, Long warehouseId, Long locationId, Long itemId, String batchNo,
            String quantity, String lockedQuantity)
    {
        WmsStock stock = new WmsStock();
        stock.setStockId(stockId);
        stock.setWarehouseId(warehouseId);
        stock.setLocationId(locationId);
        stock.setItemId(itemId);
        stock.setBatchNo(batchNo);
        stock.setQuantity(new BigDecimal(quantity));
        stock.setLockedQuantity(new BigDecimal(lockedQuantity));
        return stock;
    }

    private WmsStockTransferRequest transferRequest(Long stockId, Long targetLocationId, String quantity)
    {
        WmsStockTransferRequest request = new WmsStockTransferRequest();
        request.setStockId(stockId);
        request.setTargetLocationId(targetLocationId);
        request.setQuantity(new BigDecimal(quantity));
        request.setRemark("补货调拨");
        return request;
    }

    private WmsStockAdjustRequest adjustRequest(Long stockId, String countedQuantity)
    {
        WmsStockAdjustRequest request = new WmsStockAdjustRequest();
        request.setStockId(stockId);
        request.setCountedQuantity(new BigDecimal(countedQuantity));
        request.setRemark("月度盘点");
        return request;
    }
}
