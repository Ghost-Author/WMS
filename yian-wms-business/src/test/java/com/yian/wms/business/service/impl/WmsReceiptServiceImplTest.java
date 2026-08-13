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
import com.yian.wms.business.domain.WmsLocation;
import com.yian.wms.business.domain.WmsReceipt;
import com.yian.wms.business.domain.WmsReceiptLine;
import com.yian.wms.business.domain.WmsStock;
import com.yian.wms.business.mapper.WmsLocationMapper;
import com.yian.wms.business.mapper.WmsReceiptMapper;
import com.yian.wms.business.mapper.WmsStockMapper;
import com.yian.wms.common.exception.ServiceException;

@ExtendWith(MockitoExtension.class)
class WmsReceiptServiceImplTest
{
    @Mock private WmsReceiptMapper receiptMapper;
    @Mock private WmsStockMapper stockMapper;
    @Mock private WmsDocumentValidator validator;
    @Mock private WmsLocationMapper locationMapper;

    private WmsReceiptServiceImpl service;

    @BeforeEach
    void setUp()
    {
        service = new WmsReceiptServiceImpl(receiptMapper, stockMapper, validator, locationMapper);
    }

    @Test
    void cancelReceiptMarksDraftAsCancelled()
    {
        when(receiptMapper.selectReceiptForUpdate(11L)).thenReturn(receipt("IN-DEMO-001", "DRAFT"));
        when(receiptMapper.markCancelled(11L, "operator")).thenReturn(1);

        service.cancelReceipt(11L, "operator");

        verify(receiptMapper).markCancelled(11L, "operator");
    }

    @ParameterizedTest
    @ValueSource(strings = { "COMPLETED", "CANCELLED" })
    void cancelReceiptRejectsNonDraftDocumentWithoutWriting(String status)
    {
        when(receiptMapper.selectReceiptForUpdate(11L)).thenReturn(receipt("IN-DEMO-001", status));

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.cancelReceipt(11L, "operator"));

        assertTrue(error.getMessage().contains("不是草稿状态"));
        verify(receiptMapper, never()).markCancelled(11L, "operator");
    }

    @Test
    void cancelReceiptRejectsConcurrentStatusChange()
    {
        when(receiptMapper.selectReceiptForUpdate(11L)).thenReturn(receipt("IN-DEMO-001", "DRAFT"));
        when(receiptMapper.markCancelled(11L, "operator")).thenReturn(0);

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.cancelReceipt(11L, "operator"));

        assertTrue(error.getMessage().contains("状态已变更"));
    }

    @Test
    void completeReceiptRejectsAlreadyCompletedDocumentBeforeInventoryWrites()
    {
        when(receiptMapper.selectReceiptForUpdate(11L)).thenReturn(receipt("IN-DEMO-001", "COMPLETED"));

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.completeReceipt(11L, "operator"));

        assertTrue(error.getMessage().contains("不是草稿状态"));
        verify(receiptMapper, never()).selectLinesByReceiptId(any());
        verify(locationMapper, never()).selectLocationByIdForUpdate(any());
        verify(stockMapper, never()).upsertStock(any());
        verify(stockMapper, never()).insertMovement(any());
        verify(receiptMapper, never()).markCompleted(any(), any(), any());
    }

    @Test
    void completeReceiptRejectsLocationCapacityOverflowBeforeInventoryWrites()
    {
        WmsReceipt receipt = receipt("IN-DEMO-002", "DRAFT");
        receipt.setWarehouseId(1L);
        WmsReceiptLine line = receiptLine(10L, 7L, "B-001", "2");
        WmsLocation location = new WmsLocation();
        location.setLocationId(10L);
        location.setLocationCode("A-01-01");
        location.setStatus("0");
        location.setCapacityQty(new BigDecimal("10"));
        when(receiptMapper.selectReceiptForUpdate(11L)).thenReturn(receipt);
        when(receiptMapper.selectLinesByReceiptId(11L)).thenReturn(List.of(line));
        when(locationMapper.selectLocationByIdForUpdate(10L)).thenReturn(location);
        when(stockMapper.selectTotalQuantityByLocation(10L)).thenReturn(new BigDecimal("9"));

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.completeReceipt(11L, "operator"));

        assertTrue(error.getMessage().contains("容量不足"));
        verify(stockMapper, never()).upsertStock(any());
        verify(stockMapper, never()).insertMovement(any());
        verify(receiptMapper, never()).markCompleted(any(), any(), any());
    }

    @Test
    void completeReceiptUpsertsStockCreatesMovementAndMarksDocumentCompleted()
    {
        WmsReceipt receipt = receipt("IN-DEMO-003", "DRAFT");
        receipt.setWarehouseId(1L);
        WmsReceiptLine line = receiptLine(10L, 7L, "B-001", "2");
        List<WmsReceiptLine> lines = new ArrayList<>(List.of(line));
        WmsLocation location = new WmsLocation();
        location.setLocationId(10L);
        location.setLocationCode("A-01-01");
        location.setStatus("0");
        location.setCapacityQty(new BigDecimal("10"));
        WmsStock balance = new WmsStock();
        balance.setQuantity(new BigDecimal("6"));

        when(receiptMapper.selectReceiptForUpdate(11L)).thenReturn(receipt);
        when(receiptMapper.selectLinesByReceiptId(11L)).thenReturn(lines);
        when(locationMapper.selectLocationByIdForUpdate(10L)).thenReturn(location);
        when(stockMapper.selectTotalQuantityByLocation(10L)).thenReturn(new BigDecimal("4"));
        when(stockMapper.upsertStock(any())).thenReturn(1);
        when(stockMapper.selectStockByKey(1L, 10L, 7L, "B-001")).thenReturn(balance);
        when(stockMapper.insertMovement(any())).thenReturn(1);
        when(receiptMapper.markCompleted(11L, new BigDecimal("2"), "operator")).thenReturn(1);

        service.completeReceipt(11L, "operator");

        verify(stockMapper).upsertStock(argThat(stock ->
                Long.valueOf(1L).equals(stock.getWarehouseId())
                        && Long.valueOf(10L).equals(stock.getLocationId())
                        && Long.valueOf(7L).equals(stock.getItemId())
                        && "B-001".equals(stock.getBatchNo())
                        && new BigDecimal("2").equals(stock.getQuantity())));
        verify(stockMapper).insertMovement(argThat(movement ->
                "RECEIPT".equals(movement.getBizType())
                        && "IN-DEMO-003".equals(movement.getBizNo())
                        && Long.valueOf(1L).equals(movement.getWarehouseId())
                        && Long.valueOf(10L).equals(movement.getLocationId())
                        && Long.valueOf(7L).equals(movement.getItemId())
                        && "B-001".equals(movement.getBatchNo())
                        && new BigDecimal("2").equals(movement.getChangeQty())
                        && new BigDecimal("6").equals(movement.getBalanceQty())
                        && "operator".equals(movement.getOperator())));
        verify(receiptMapper).markCompleted(11L, new BigDecimal("2"), "operator");
    }

    private WmsReceipt receipt(String receiptNo, String status)
    {
        WmsReceipt receipt = new WmsReceipt();
        receipt.setReceiptNo(receiptNo);
        receipt.setStatus(status);
        return receipt;
    }

    private WmsReceiptLine receiptLine(Long locationId, Long itemId, String batchNo, String receivedQty)
    {
        WmsReceiptLine line = new WmsReceiptLine();
        line.setLocationId(locationId);
        line.setItemId(itemId);
        line.setBatchNo(batchNo);
        line.setReceivedQty(new BigDecimal(receivedQty));
        return line;
    }
}
