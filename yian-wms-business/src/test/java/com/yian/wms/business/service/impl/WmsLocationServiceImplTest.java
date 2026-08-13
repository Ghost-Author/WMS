package com.yian.wms.business.service.impl;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import com.yian.wms.business.domain.WmsArea;
import com.yian.wms.business.domain.WmsLocation;
import com.yian.wms.business.domain.WmsWarehouse;
import com.yian.wms.business.mapper.WmsAreaMapper;
import com.yian.wms.business.mapper.WmsLocationMapper;
import com.yian.wms.business.mapper.WmsStockMapper;
import com.yian.wms.business.mapper.WmsWarehouseMapper;
import com.yian.wms.common.exception.ServiceException;

@ExtendWith(MockitoExtension.class)
class WmsLocationServiceImplTest
{
    @Mock private WmsLocationMapper locationMapper;
    @Mock private WmsStockMapper stockMapper;
    @Mock private WmsAreaMapper areaMapper;
    @Mock private WmsWarehouseMapper warehouseMapper;

    private WmsLocationServiceImpl service;

    @BeforeEach
    void setUp()
    {
        service = new WmsLocationServiceImpl(locationMapper, stockMapper, areaMapper, warehouseMapper);
    }

    @Test
    void updateLocationRejectsCapacityBelowCurrentStock()
    {
        stubExistingLocation("NORMAL", "0", "100");

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.updateLocation(location("NORMAL", "0", "99")));

        assertTrue(error.getMessage().contains("容量不能下调"));
        verify(locationMapper, never()).updateLocation(any());
    }

    @Test
    void updateLocationRejectsDisablingAStockedLocation()
    {
        stubExistingLocation("NORMAL", "0", "20");

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.updateLocation(location("NORMAL", "1", "100")));

        assertTrue(error.getMessage().contains("仍有库存，不能停用"));
        verify(locationMapper, never()).updateLocation(any());
    }

    @Test
    void updateLocationRejectsChangingAStockedLocationToDefective()
    {
        stubExistingLocation("NORMAL", "0", "20");

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.updateLocation(location("DEFECTIVE", "0", "100")));

        assertTrue(error.getMessage().contains("不能直接改为不良品库位"));
        verify(locationMapper, never()).updateLocation(any());
    }

    @Test
    void updateLocationAllowsCapacityEqualToCurrentStock()
    {
        stubExistingLocation("NORMAL", "0", "20");
        when(locationMapper.countReferences(10L)).thenReturn(1);
        when(locationMapper.updateLocation(any(WmsLocation.class))).thenReturn(1);

        int rows = service.updateLocation(location("NORMAL", "0", "20"));

        assertEquals(1, rows);
        verify(locationMapper).updateLocation(any(WmsLocation.class));
    }

    private void stubExistingLocation(String type, String status, String currentQuantity)
    {
        when(locationMapper.selectLocationByIdForUpdate(10L)).thenReturn(location(type, status, "100"));
        when(stockMapper.selectTotalQuantityByLocation(10L)).thenReturn(new BigDecimal(currentQuantity));
        when(locationMapper.countCode(1L, "A-01-01", 10L)).thenReturn(0);

        WmsWarehouse warehouse = new WmsWarehouse();
        warehouse.setWarehouseId(1L);
        warehouse.setStatus("0");
        when(warehouseMapper.selectWarehouseById(1L)).thenReturn(warehouse);

        WmsArea area = new WmsArea();
        area.setAreaId(101L);
        area.setWarehouseId(1L);
        area.setStatus("0");
        when(areaMapper.selectAreaById(101L)).thenReturn(area);
    }

    private WmsLocation location(String type, String status, String capacity)
    {
        WmsLocation location = new WmsLocation();
        location.setLocationId(10L);
        location.setWarehouseId(1L);
        location.setAreaId(101L);
        location.setLocationCode("A-01-01");
        location.setLocationName("测试库位");
        location.setLocationType(type);
        location.setCapacityQty(new BigDecimal(capacity));
        location.setStatus(status);
        return location;
    }
}
