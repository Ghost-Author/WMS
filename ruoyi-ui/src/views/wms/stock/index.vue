<template>
  <div class="app-container wms-page">
    <div class="page-heading">
      <div><h2>库存中心</h2><p>实时查看批次库存、安全库存预警与每一次库存变动。</p></div>
      <el-tag type="success" effect="light">实时库存</el-tag>
    </div>

    <el-card shadow="never" class="content-card">
      <el-tabs v-model="activeTab" @tab-change="handleTabChange">
        <el-tab-pane label="库存查询" name="stock">
          <el-form ref="stockQueryRef" :model="stockQuery" :inline="true" class="query-form">
            <el-form-item label="仓库" prop="warehouseId"><el-select v-model="stockQuery.warehouseId" placeholder="全部仓库" clearable filterable style="width: 210px" @change="loadLocations"><el-option v-for="item in warehouses" :key="item.warehouseId" :label="optionText(item, 'warehouseCode', 'warehouseName')" :value="item.warehouseId" /></el-select></el-form-item>
            <el-form-item v-if="!onlyLowStock" label="库位" prop="locationId"><el-select v-model="stockQuery.locationId" placeholder="全部库位" clearable filterable style="width: 190px"><el-option v-for="item in locations" :key="item.locationId" :label="optionText(item, 'locationCode', 'locationName')" :value="item.locationId" /></el-select></el-form-item>
            <el-form-item label="物料" prop="itemId"><el-select v-model="stockQuery.itemId" placeholder="全部物料" clearable filterable style="width: 220px"><el-option v-for="item in items" :key="item.itemId" :label="optionText(item, 'itemCode', 'itemName')" :value="item.itemId" /></el-select></el-form-item>
            <el-form-item v-if="!onlyLowStock" label="批次" prop="batchNo"><el-input v-model="stockQuery.batchNo" placeholder="请输入批次号" clearable @keyup.enter="queryStock" /></el-form-item>
            <el-form-item><el-button type="primary" icon="Search" @click="queryStock">查询</el-button><el-button icon="Refresh" @click="resetStockQuery">重置</el-button></el-form-item>
          </el-form>
          <div class="stock-toolbar">
            <div class="low-stock-switch"><el-switch v-model="onlyLowStock" inline-prompt active-text="预警" inactive-text="全部" @change="handleLowStockChange" /><span>仅显示低库存物料</span></div>
            <el-button icon="Refresh" circle @click="getStockList" title="刷新库存" />
          </div>
          <el-table v-loading="stockLoading" :data="stockList" stripe>
            <el-table-column label="仓库" prop="warehouseName" min-width="130" show-overflow-tooltip />
            <el-table-column label="库位" min-width="145" show-overflow-tooltip><template #default="scope"><div>{{ scope.row.locationCode }}</div><small class="muted">{{ scope.row.locationName }}</small></template></el-table-column>
            <el-table-column label="物料" min-width="190" show-overflow-tooltip><template #default="scope"><div class="item-cell"><span>{{ scope.row.itemCode }}</span><el-tag v-if="isLow(scope.row)" type="danger" size="small" effect="light">低库存</el-tag></div><small class="muted">{{ scope.row.itemName }}<template v-if="scope.row.specification"> · {{ scope.row.specification }}</template></small></template></el-table-column>
            <el-table-column label="批次" prop="batchNo" min-width="120"><template #default="scope">{{ scope.row.batchNo || '-' }}</template></el-table-column>
            <el-table-column label="库存数量" width="115" align="right"><template #default="scope"><strong>{{ quantity(stockQty(scope.row)) }}</strong> {{ scope.row.unit || '' }}</template></el-table-column>
            <el-table-column label="锁定数量" prop="lockedQuantity" width="105" align="right"><template #default="scope">{{ quantity(lockedQty(scope.row)) }}</template></el-table-column>
            <el-table-column label="可用数量" prop="availableQty" width="105" align="right"><template #default="scope"><span :class="{ danger: Number(availableQty(scope.row)) <= 0 }">{{ quantity(availableQty(scope.row)) }}</span></template></el-table-column>
            <el-table-column label="生产日期" prop="productionDate" width="115"><template #default="scope">{{ parseDate(scope.row.productionDate) }}</template></el-table-column>
            <el-table-column label="有效期至" prop="expiryDate" width="115"><template #default="scope"><span :class="expiryClass(scope.row.expiryDate)">{{ parseDate(scope.row.expiryDate) }}</span></template></el-table-column>
            <el-table-column v-if="!onlyLowStock" label="操作" width="90" fixed="right" align="center"><template #default="scope"><el-button link type="primary" icon="List" @click="openMovements(scope.row)" v-hasPermi="['wms:stock:list']">流水</el-button></template></el-table-column>
          </el-table>
          <pagination v-show="stockTotal > 0" :total="stockTotal" v-model:page="stockQuery.pageNum" v-model:limit="stockQuery.pageSize" @pagination="getStockList" />
        </el-tab-pane>

        <el-tab-pane label="库存流水" name="movement">
          <el-form ref="movementQueryRef" :model="movementQuery" :inline="true" class="query-form">
            <el-form-item label="业务类型" prop="bizType"><el-select v-model="movementQuery.bizType" placeholder="全部类型" clearable style="width: 150px"><el-option v-for="item in movementTypes" :key="item.value" :label="item.label" :value="item.value" /></el-select></el-form-item>
            <el-form-item label="业务单号" prop="bizNo"><el-input v-model="movementQuery.bizNo" placeholder="请输入业务单号" clearable @keyup.enter="queryMovements" /></el-form-item>
            <el-form-item label="物料" prop="itemId"><el-select v-model="movementQuery.itemId" placeholder="全部物料" clearable filterable style="width: 220px"><el-option v-for="item in items" :key="item.itemId" :label="optionText(item, 'itemCode', 'itemName')" :value="item.itemId" /></el-select></el-form-item>
            <el-form-item label="操作时间"><el-date-picker v-model="movementDateRange" value-format="YYYY-MM-DD" type="daterange" range-separator="至" start-placeholder="开始日期" end-placeholder="结束日期" style="width: 260px" /></el-form-item>
            <el-form-item><el-button type="primary" icon="Search" @click="queryMovements">查询</el-button><el-button icon="Refresh" @click="resetMovementQuery">重置</el-button></el-form-item>
          </el-form>
          <div v-loading="movementLoading"><movement-table :rows="movementList" /></div>
          <pagination v-show="movementTotal > 0" :total="movementTotal" v-model:page="movementQuery.pageNum" v-model:limit="movementQuery.pageSize" @pagination="getMovementList" />
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <el-drawer v-model="drawerOpen" title="库存变动明细" size="min(920px, 92vw)" append-to-body>
      <el-descriptions v-if="drawerStock" :column="2" border class="drawer-summary">
        <el-descriptions-item label="物料">{{ drawerStock.itemCode }} - {{ drawerStock.itemName }}</el-descriptions-item>
        <el-descriptions-item label="库位">{{ drawerStock.locationCode }} - {{ drawerStock.locationName }}</el-descriptions-item>
        <el-descriptions-item label="批次">{{ drawerStock.batchNo || '-' }}</el-descriptions-item>
        <el-descriptions-item label="当前库存">{{ quantity(stockQty(drawerStock)) }} {{ drawerStock.unit || '' }}</el-descriptions-item>
      </el-descriptions>
      <div v-loading="drawerLoading"><movement-table :rows="drawerMovements" /></div>
      <pagination v-show="drawerTotal > 0" :total="drawerTotal" v-model:page="drawerQuery.pageNum" v-model:limit="drawerQuery.pageSize" @pagination="getDrawerMovements" />
    </el-drawer>
  </div>
</template>

<script setup name="WmsStock">
import { defineComponent, h } from 'vue'
import { ElTable, ElTableColumn, ElTag } from 'element-plus'
import { getItemOptions } from '@/api/wms/item'
import { getLocationOptions } from '@/api/wms/location'
import { listLowStock, listStock, listStockMovements } from '@/api/wms/stock'
import { getWarehouseOptions } from '@/api/wms/warehouse'
import { optionText, quantity, rowsOf, totalOf } from '@/views/wms/utils'

const { proxy } = getCurrentInstance()
const route = useRoute()
const movementTypes = [
  { value: 'INITIAL', label: '期初' }, { value: 'RECEIPT', label: '入库' }, { value: 'SHIPMENT', label: '出库' },
  { value: 'ADJUST_IN', label: '盘盈' }, { value: 'ADJUST_OUT', label: '盘亏' }
]
const movementTypeLabel = value => movementTypes.find(item => item.value === value)?.label || value || '-'
const MovementTable = defineComponent({
  name: 'MovementTable',
  props: { rows: { type: Array, default: () => [] } },
  setup(props) {
    const column = (label, prop, width, options = {}) => h(ElTableColumn, { label, prop, width, ...options })
    return () => h(ElTable, { data: props.rows, stripe: true }, {
      default: () => [
        h(ElTableColumn, { label: '业务类型', width: 100, align: 'center' }, { default: ({ row }) => h(ElTag, { type: Number(row.changeQty) >= 0 ? 'success' : 'warning', effect: 'light' }, () => movementTypeLabel(row.bizType)) }),
        column('业务单号', 'bizNo', undefined, { minWidth: 160, showOverflowTooltip: true }),
        column('仓库', 'warehouseName', undefined, { minWidth: 120, showOverflowTooltip: true }),
        column('库位', 'locationCode', undefined, { minWidth: 120, showOverflowTooltip: true }),
        column('物料编码', 'itemCode', undefined, { minWidth: 120 }),
        column('物料名称', 'itemName', undefined, { minWidth: 140, showOverflowTooltip: true }),
        column('批次', 'batchNo', undefined, { minWidth: 110 }),
        h(ElTableColumn, { label: '变动数量', width: 105, align: 'right' }, { default: ({ row }) => h('span', { class: Number(row.changeQty) >= 0 ? 'increase' : 'decrease' }, `${Number(row.changeQty) > 0 ? '+' : ''}${quantity(row.changeQty)}`) }),
        h(ElTableColumn, { label: '结存数量', width: 105, align: 'right' }, { default: ({ row }) => quantity(row.balanceQty) }),
        column('操作人', 'operator', 105),
        h(ElTableColumn, { label: '操作时间', width: 170 }, { default: ({ row }) => proxy.parseTime(row.operationTime) || '-' })
      ]
    })
  }
})

const activeTab = ref('stock')
const stockLoading = ref(false)
const movementLoading = ref(false)
const drawerLoading = ref(false)
const onlyLowStock = ref(route.query.lowStock === '1')
const warehouses = ref([])
const locations = ref([])
const items = ref([])
const stockList = ref([])
const movementList = ref([])
const drawerMovements = ref([])
const stockTotal = ref(0)
const movementTotal = ref(0)
const drawerTotal = ref(0)
const movementDateRange = ref([])
const drawerOpen = ref(false)
const drawerStock = ref(null)
const stockQuery = reactive({ pageNum: 1, pageSize: 10, warehouseId: undefined, locationId: undefined, itemId: route.query.itemId || undefined, batchNo: undefined })
const movementQuery = reactive({ pageNum: 1, pageSize: 10, bizType: undefined, bizNo: undefined, itemId: undefined })
const drawerQuery = reactive({ pageNum: 1, pageSize: 10, itemId: undefined, locationId: undefined, batchNo: undefined, exactBatch: true })

function stockQty(row) { return row.quantity ?? row.stockQty ?? 0 }
function lockedQty(row) { return row.lockedQuantity ?? row.lockedQty ?? 0 }
function availableQty(row) { return row.availableQty ?? (Number(stockQty(row)) - Number(lockedQty(row))) }
function isLow(row) { return row.lowStock === true || row.isLowStock === true || (row.minStock != null && Number(availableQty(row)) <= Number(row.minStock)) }
function parseDate(value) { return value ? String(value).slice(0, 10) : '-' }
function expiryClass(value) { if (!value) return ''; const days = (new Date(value).getTime() - Date.now()) / 86400000; return days < 0 ? 'expired' : days <= 30 ? 'expiring' : '' }
async function loadOptions() { const [warehouseRes, itemRes] = await Promise.all([getWarehouseOptions({ status: '0' }), getItemOptions({ status: '0' })]); warehouses.value = rowsOf(warehouseRes); items.value = rowsOf(itemRes) }
async function loadLocations(warehouseId) { stockQuery.locationId = undefined; locations.value = rowsOf(await getLocationOptions({ warehouseId, status: '0' })) }
async function getStockList() { stockLoading.value = true; try { const response = await (onlyLowStock.value ? listLowStock(stockQuery) : listStock(stockQuery)); stockList.value = rowsOf(response); stockTotal.value = totalOf(response, stockList.value) } finally { stockLoading.value = false } }
function queryStock() { stockQuery.pageNum = 1; getStockList() }
function handleLowStockChange(enabled) { if (enabled) { stockQuery.locationId = undefined; stockQuery.batchNo = undefined } queryStock() }
function resetStockQuery() { proxy.resetForm('stockQueryRef'); locations.value = []; onlyLowStock.value = false; queryStock() }
function movementParams(query) { return proxy.addDateRange({ ...query }, movementDateRange.value) }
async function getMovementList() { movementLoading.value = true; try { const response = await listStockMovements(movementParams(movementQuery)); movementList.value = rowsOf(response); movementTotal.value = totalOf(response, movementList.value) } finally { movementLoading.value = false } }
function queryMovements() { movementQuery.pageNum = 1; getMovementList() }
function resetMovementQuery() { proxy.resetForm('movementQueryRef'); movementDateRange.value = []; queryMovements() }
function handleTabChange(name) { if (name === 'movement' && !movementList.value.length) getMovementList() }
async function openMovements(row) { drawerStock.value = row; Object.assign(drawerQuery, { pageNum: 1, itemId: row.itemId, locationId: row.locationId, batchNo: row.batchNo ?? '', exactBatch: true }); drawerOpen.value = true; getDrawerMovements() }
async function getDrawerMovements() { drawerLoading.value = true; try { const response = await listStockMovements(drawerQuery); drawerMovements.value = rowsOf(response); drawerTotal.value = totalOf(response, drawerMovements.value) } finally { drawerLoading.value = false } }

function routeItemId(value) { const id = Number(value); return value !== undefined && value !== '' && Number.isFinite(id) ? id : undefined }
function syncRouteQuery() {
  onlyLowStock.value = route.query.lowStock === '1'
  stockQuery.itemId = routeItemId(route.query.itemId)
  if (onlyLowStock.value) { stockQuery.locationId = undefined; stockQuery.batchNo = undefined }
}

watch(() => [route.query.lowStock, route.query.itemId], () => { syncRouteQuery(); queryStock() })
onActivated(() => { syncRouteQuery(); getStockList() })

syncRouteQuery()
loadOptions()
getStockList()
</script>

<style scoped lang="scss">
.wms-page { background: #f6f8fb; min-height: calc(100vh - 84px); }
.page-heading { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; h2 { margin: 0 0 6px; font-size: 22px; color: #1d2939; } p { margin: 0; color: #667085; } }
.content-card :deep(.el-card__body) { padding: 10px 18px 18px; }
.query-form { padding: 12px 0 0; border-bottom: 1px solid #eaecf0; margin-bottom: 14px; }
.stock-toolbar { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; }
.low-stock-switch { display: flex; align-items: center; gap: 10px; color: #475467; }
.item-cell { display: flex; align-items: center; gap: 8px; }
.muted { color: #98a2b3; }
.danger, .expired, :deep(.decrease) { color: #f04438; font-weight: 600; }
.expiring { color: #f79009; font-weight: 600; }
:deep(.increase) { color: #12b76a; font-weight: 600; }
.drawer-summary { margin-bottom: 18px; }
@media (max-width: 768px) { .page-heading { align-items: flex-start; gap: 12px; } .page-heading p { display: none; } }
</style>
