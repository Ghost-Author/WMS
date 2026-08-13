package com.yian.wms.business.service.impl;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import com.yian.wms.business.domain.WmsShipment;
import com.yian.wms.business.domain.WmsShipmentLine;
import com.yian.wms.business.domain.WmsStock;
import com.yian.wms.business.mapper.WmsShipmentMapper;
import com.yian.wms.business.mapper.WmsStockMapper;
import com.yian.wms.common.exception.ServiceException;

@ExtendWith(MockitoExtension.class)
class WmsShipmentServiceImplTest
{
    @Mock private WmsShipmentMapper shipmentMapper;
    @Mock private WmsStockMapper stockMapper;
    @Mock private WmsDocumentValidator validator;

    private WmsShipmentServiceImpl service;

    @BeforeEach
    void setUp()
    {
        service = new WmsShipmentServiceImpl(shipmentMapper, stockMapper, validator);
    }

    @Test
    void cancelShipmentMarksDraftAsCancelled()
    {
        when(shipmentMapper.selectShipmentForUpdate(21L)).thenReturn(shipment("OUT-DEMO-001", "DRAFT"));
        when(shipmentMapper.markCancelled(21L, "operator")).thenReturn(1);

        service.cancelShipment(21L, "operator");

        verify(shipmentMapper).markCancelled(21L, "operator");
    }

    @ParameterizedTest
    @ValueSource(strings = { "COMPLETED", "CANCELLED" })
    void cancelShipmentRejectsNonDraftDocumentWithoutWriting(String status)
    {
        when(shipmentMapper.selectShipmentForUpdate(21L)).thenReturn(shipment("OUT-DEMO-001", status));

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.cancelShipment(21L, "operator"));

        assertTrue(error.getMessage().contains("不是草稿状态"));
        verify(shipmentMapper, never()).markCancelled(21L, "operator");
    }

    @Test
    void cancelShipmentRejectsConcurrentStatusChange()
    {
        when(shipmentMapper.selectShipmentForUpdate(21L)).thenReturn(shipment("OUT-DEMO-001", "DRAFT"));
        when(shipmentMapper.markCancelled(21L, "operator")).thenReturn(0);

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.cancelShipment(21L, "operator"));

        assertTrue(error.getMessage().contains("状态已变更"));
    }

    @Test
    void completeShipmentRejectsFailedAtomicDecreaseWithoutMovement()
    {
        WmsShipment shipment = shipment("OUT-DEMO-002", "DRAFT");
        shipment.setWarehouseId(1L);
        shipment.setShipmentType("SALE");
        WmsShipmentLine line = shipmentLine(10L, 7L, "B-001", "3");
        WmsStock before = stock("10", "10");
        WmsStock current = stock("2", "2");
        when(shipmentMapper.selectShipmentForUpdate(21L)).thenReturn(shipment);
        when(shipmentMapper.selectLinesByShipmentId(21L)).thenReturn(new ArrayList<>(List.of(line)));
        when(stockMapper.selectStockByKey(1L, 10L, 7L, "B-001")).thenReturn(before, current);
        when(stockMapper.decreaseStock(1L, 10L, 7L, "B-001", new BigDecimal("3"))).thenReturn(0);

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.completeShipment(21L, "operator"));

        assertTrue(error.getMessage().contains("库存不足"));
        verify(stockMapper, never()).insertMovement(any());
        verify(shipmentMapper, never()).markCompleted(any(), any(), any());
    }

    @Test
    void completeShipmentAtomicallyDecreasesStockCreatesMovementAndMarksDocumentCompleted()
    {
        WmsShipment shipment = shipment("OUT-DEMO-003", "DRAFT");
        shipment.setWarehouseId(1L);
        shipment.setShipmentType("SALE");
        WmsShipmentLine line = shipmentLine(10L, 7L, "B-001", "3");
        WmsStock before = stock("10", "10");
        WmsStock balance = stock("7", "7");

        when(shipmentMapper.selectShipmentForUpdate(21L)).thenReturn(shipment);
        when(shipmentMapper.selectLinesByShipmentId(21L)).thenReturn(new ArrayList<>(List.of(line)));
        when(stockMapper.selectStockByKey(1L, 10L, 7L, "B-001")).thenReturn(before, balance);
        when(stockMapper.decreaseStock(1L, 10L, 7L, "B-001", new BigDecimal("3"))).thenReturn(1);
        when(stockMapper.insertMovement(any())).thenReturn(1);
        when(shipmentMapper.markCompleted(21L, new BigDecimal("3"), "operator")).thenReturn(1);

        service.completeShipment(21L, "operator");

        verify(stockMapper).decreaseStock(1L, 10L, 7L, "B-001", new BigDecimal("3"));
        verify(stockMapper).insertMovement(argThat(movement ->
                "SHIPMENT".equals(movement.getBizType())
                        && "OUT-DEMO-003".equals(movement.getBizNo())
                        && Long.valueOf(1L).equals(movement.getWarehouseId())
                        && Long.valueOf(10L).equals(movement.getLocationId())
                        && Long.valueOf(7L).equals(movement.getItemId())
                        && "B-001".equals(movement.getBatchNo())
                        && new BigDecimal("-3").equals(movement.getChangeQty())
                        && new BigDecimal("7").equals(movement.getBalanceQty())
                        && "operator".equals(movement.getOperator())));
        verify(shipmentMapper).markCompleted(21L, new BigDecimal("3"), "operator");
    }

    private WmsShipment shipment(String shipmentNo, String status)
    {
        WmsShipment shipment = new WmsShipment();
        shipment.setShipmentNo(shipmentNo);
        shipment.setStatus(status);
        return shipment;
    }

    private WmsShipmentLine shipmentLine(Long locationId, Long itemId, String batchNo, String shippedQty)
    {
        WmsShipmentLine line = new WmsShipmentLine();
        line.setLocationId(locationId);
        line.setItemId(itemId);
        line.setBatchNo(batchNo);
        line.setShippedQty(new BigDecimal(shippedQty));
        return line;
    }

    private WmsStock stock(String quantity, String availableQty)
    {
        WmsStock stock = new WmsStock();
        stock.setQuantity(new BigDecimal(quantity));
        stock.setAvailableQty(new BigDecimal(availableQty));
        stock.setItemCode("ITEM-007");
        stock.setLocationCode("A-01-01");
        stock.setBatchNo("B-001");
        return stock;
    }
}
