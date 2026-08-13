package com.yian.wms.business.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletResponse;
import com.yian.wms.business.domain.WmsStock;
import com.yian.wms.business.domain.WmsStockMovement;
import com.yian.wms.common.utils.poi.ExcelUtil;

class WmsStockExportContractTest
{
    @Test
    void movementWorkbookExportsNonBlankReasonAndMapperHydratesBothRemarkProperties() throws Exception
    {
        String reason = "盘点差异复核";
        WmsStockMovement movement = new WmsStockMovement();
        movement.setBizType("ADJUST_OUT");
        movement.setBizNo("ADJ-DEMO-001");
        movement.setChangeQty(new BigDecimal("-2"));
        movement.setBalanceQty(new BigDecimal("8"));
        movement.setRemark(reason);
        movement.setExportRemark(reason);

        try (Workbook workbook = exportWorkbook(WmsStockMovement.class, movement, "库存流水"))
        {
            String exportedReason = exportedValue(workbook, "备注/原因");
            assertFalse(exportedReason.isBlank());
            assertEquals(reason, exportedReason);
        }

        String mapperXml;
        try (InputStream input = WmsStockExportContractTest.class.getResourceAsStream(
                "/mapper/wms/WmsStockMapper.xml"))
        {
            assertNotNull(input, "WmsStockMapper.xml must be available on the test classpath");
            mapperXml = new String(input.readAllBytes(), StandardCharsets.UTF_8);
        }
        int resultMapStart = mapperXml.indexOf("<resultMap id=\"MovementResult\"");
        int resultMapEnd = mapperXml.indexOf("</resultMap>", resultMapStart);
        assertTrue(resultMapStart >= 0 && resultMapEnd > resultMapStart,
                "MovementResult mapping must exist");
        String movementResultMap = mapperXml.substring(resultMapStart, resultMapEnd);
        assertTrue(movementResultMap.contains("<result property=\"remark\" column=\"remark\"/>"),
                "remark must remain available to API consumers");
        assertTrue(movementResultMap.contains("<result property=\"exportRemark\" column=\"remark\"/>"),
                "the same remark column must hydrate the Excel export field");
    }

    @Test
    void stockWorkbookExportsSafetyStockThreshold() throws Exception
    {
        WmsStock stock = new WmsStock();
        stock.setItemCode("ITEM-001");
        stock.setMinStock(new BigDecimal("12.5000"));

        try (Workbook workbook = exportWorkbook(WmsStock.class, stock, "库存余额"))
        {
            assertEquals("12.5000", exportedValue(workbook, "安全库存下限"));
        }
    }

    private static <T> Workbook exportWorkbook(Class<T> type, T row, String sheetName) throws Exception
    {
        MockHttpServletResponse response = new MockHttpServletResponse();
        new ExcelUtil<T>(type).exportExcel(response, List.of(row), sheetName);
        byte[] workbookBytes = response.getContentAsByteArray();
        assertTrue(workbookBytes.length > 0, "ExcelUtil must write a workbook to the response");
        return WorkbookFactory.create(new ByteArrayInputStream(workbookBytes));
    }

    private static String exportedValue(Workbook workbook, String header)
    {
        Sheet sheet = workbook.getSheetAt(0);
        Row headerRow = sheet.getRow(0);
        assertNotNull(headerRow, "exported workbook must contain a header row");
        DataFormatter formatter = new DataFormatter();
        int column = -1;
        for (Cell cell : headerRow)
        {
            if (header.equals(formatter.formatCellValue(cell)))
            {
                column = cell.getColumnIndex();
                break;
            }
        }
        assertTrue(column >= 0, "missing export column: " + header);
        Row dataRow = sheet.getRow(headerRow.getRowNum() + 1);
        assertNotNull(dataRow, "exported workbook must contain a data row");
        Cell dataCell = dataRow.getCell(column);
        assertNotNull(dataCell, "missing data cell for export column: " + header);
        return formatter.formatCellValue(dataCell);
    }
}
