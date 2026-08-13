package com.yian.wms.business.mapper;

import java.math.BigDecimal;
import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.yian.wms.business.domain.WmsStock;
import com.yian.wms.business.domain.WmsStockMovement;

public interface WmsStockMapper
{
    List<WmsStock> selectStockList(WmsStock stock);
    List<WmsStock> selectLowStockList(WmsStock stock);
    List<WmsStockMovement> selectMovementList(WmsStockMovement movement);
    WmsStock selectStockById(Long stockId);
    WmsStock selectStockByIdForUpdate(Long stockId);
    WmsStock selectStockByKey(@Param("warehouseId") Long warehouseId, @Param("locationId") Long locationId,
            @Param("itemId") Long itemId, @Param("batchNo") String batchNo);
    WmsStock selectStockByKeyForUpdate(@Param("warehouseId") Long warehouseId, @Param("locationId") Long locationId,
            @Param("itemId") Long itemId, @Param("batchNo") String batchNo);
    BigDecimal selectTotalQuantityByLocation(Long locationId);
    int upsertStock(WmsStock stock);
    int decreaseStock(@Param("warehouseId") Long warehouseId, @Param("locationId") Long locationId,
            @Param("itemId") Long itemId, @Param("batchNo") String batchNo, @Param("quantity") BigDecimal quantity);
    int decreaseStockById(@Param("stockId") Long stockId, @Param("quantity") BigDecimal quantity);
    int updateStockQuantity(@Param("stockId") Long stockId, @Param("quantity") BigDecimal quantity);
    int insertMovement(WmsStockMovement movement);
}
