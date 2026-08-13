package com.yian.wms.business.service.impl;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.lang.reflect.Method;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.yian.wms.business.domain.dto.WmsStockAdjustRequest;
import com.yian.wms.business.domain.dto.WmsStockTransferRequest;

class WmsCapacityIsolationContractTest
{
    @Test
    void capacityIncreasingCommandsUseFreshReadsAfterTheLocationLock() throws Exception
    {
        assertReadCommitted(WmsReceiptServiceImpl.class, "completeReceipt", Long.class, String.class);
        assertReadCommitted(WmsStockServiceImpl.class, "transferStock", WmsStockTransferRequest.class, String.class);
        assertReadCommitted(WmsStockServiceImpl.class, "adjustStock", WmsStockAdjustRequest.class, String.class);
        assertReadCommitted(WmsLocationServiceImpl.class, "updateLocation", com.yian.wms.business.domain.WmsLocation.class);
    }

    private void assertReadCommitted(Class<?> serviceType, String methodName, Class<?>... parameterTypes)
            throws Exception
    {
        Method method = serviceType.getMethod(methodName, parameterTypes);
        Transactional transactional = method.getAnnotation(Transactional.class);
        assertNotNull(transactional, serviceType.getSimpleName() + "." + methodName + " must be transactional");
        assertEquals(Isolation.READ_COMMITTED, transactional.isolation(),
                serviceType.getSimpleName() + "." + methodName + " must read the latest committed capacity");
    }
}
