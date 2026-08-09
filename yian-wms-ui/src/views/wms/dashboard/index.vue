<template>
  <div class="app-container dashboard-page">
    <div class="welcome-panel">
      <div>
        <span class="eyebrow">WAREHOUSE OVERVIEW</span>
        <h1>以安WMS 运营看板</h1>
        <p>{{ todayText }}，掌握仓储业务进度与库存健康度。</p>
      </div>
      <div class="welcome-mark"><el-icon><DataAnalysis /></el-icon></div>
    </div>

    <el-row :gutter="16" class="summary-grid" v-loading="summaryLoading">
      <el-col v-for="card in summaryCards" :key="card.key" :xs="12" :sm="12" :lg="6">
        <el-card shadow="hover" class="summary-card" :class="`tone-${card.tone}`">
          <div class="summary-icon"><el-icon><component :is="card.icon" /></el-icon></div>
          <div class="summary-content"><span>{{ card.label }}</span><strong>{{ quantity(card.value) }}</strong><small>{{ card.hint }}</small></div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" class="operation-row">
      <el-col :xs="24" :lg="16">
        <el-card shadow="never" class="section-card">
          <template #header><div class="section-title"><div><span>今日作业</span><small>入库与出库执行概况</small></div><el-button v-if="canViewStock" link type="primary" @click="router.push('/wms/stock')">查看库存</el-button></div></template>
          <div class="throughput">
            <div class="throughput-item inbound"><div class="throughput-icon"><el-icon><Download /></el-icon></div><div><span>今日入库</span><strong>{{ quantity(summary.todayInbound) }}</strong><small>累计入库数量</small></div></div>
            <div class="throughput-divider" />
            <div class="throughput-item outbound"><div class="throughput-icon"><el-icon><Upload /></el-icon></div><div><span>今日出库</span><strong>{{ quantity(summary.todayOutbound) }}</strong><small>累计出库数量</small></div></div>
          </div>
        </el-card>
      </el-col>
      <el-col :xs="24" :lg="8">
        <el-card shadow="never" class="section-card pending-card">
          <template #header><div class="section-title"><div><span>待处理单据</span><small>及时完成草稿单据</small></div></div></template>
          <button v-if="canViewReceipt" class="pending-item" type="button" @click="router.push('/wms/receipt')"><span class="pending-symbol receipt"><el-icon><Download /></el-icon></span><span class="pending-name">待完成入库单<small>进入入库管理</small></span><strong>{{ summary.pendingReceipt || 0 }}</strong><el-icon><ArrowRight /></el-icon></button>
          <button v-if="canViewShipment" class="pending-item" type="button" @click="router.push('/wms/shipment')"><span class="pending-symbol shipment"><el-icon><Upload /></el-icon></span><span class="pending-name">待完成出库单<small>进入出库管理</small></span><strong>{{ summary.pendingShipment || 0 }}</strong><el-icon><ArrowRight /></el-icon></button>
          <el-empty v-if="!canViewReceipt && !canViewShipment" description="暂无可访问的单据模块" :image-size="58" />
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" class="detail-row">
      <el-col :xs="24" :xl="17">
        <el-card shadow="never" class="section-card movement-card">
          <template #header><div class="section-title"><div><span>近期库存流水</span><small>最近发生的库存数量变动</small></div><el-button v-if="canViewStock" link type="primary" @click="router.push('/wms/stock')">全部流水 <el-icon><ArrowRight /></el-icon></el-button></div></template>
          <el-table :data="recentMovements" v-loading="movementLoading" height="344" empty-text="暂无库存流水">
            <el-table-column label="业务类型" width="95"><template #default="scope"><el-tag :type="Number(changeQty(scope.row)) >= 0 ? 'success' : 'warning'" effect="light">{{ movementType(scope.row.bizType) }}</el-tag></template></el-table-column>
            <el-table-column label="业务单号" prop="bizNo" min-width="155" show-overflow-tooltip />
            <el-table-column label="物料" min-width="180" show-overflow-tooltip><template #default="scope"><span>{{ scope.row.itemCode }}</span><small class="table-sub">{{ scope.row.itemName }}</small></template></el-table-column>
            <el-table-column label="库位" prop="locationCode" min-width="110" show-overflow-tooltip />
            <el-table-column label="变动" width="100" align="right"><template #default="scope"><strong :class="Number(changeQty(scope.row)) >= 0 ? 'increase' : 'decrease'">{{ Number(changeQty(scope.row)) > 0 ? '+' : '' }}{{ quantity(changeQty(scope.row)) }}</strong></template></el-table-column>
            <el-table-column label="结存" width="100" align="right"><template #default="scope">{{ quantity(balanceQty(scope.row)) }}</template></el-table-column>
            <el-table-column label="操作时间" width="165"><template #default="scope">{{ proxy.parseTime(scope.row.operationTime) || '-' }}</template></el-table-column>
          </el-table>
        </el-card>
      </el-col>
      <el-col :xs="24" :xl="7">
        <el-card shadow="never" class="section-card alert-card">
          <template #header><div class="section-title"><div><span>低库存提示</span><small>低于物料安全库存下限</small></div><el-badge :value="summary.lowStockCount || 0" :max="99" type="danger" /></div></template>
          <div v-loading="lowStockLoading" class="alert-list">
            <button v-for="row in lowStocks" :key="`${row.itemId}-${row.locationId}-${row.batchNo}`" class="alert-item" type="button" :disabled="!canViewStock" @click="goLowStock(row)">
              <span class="alert-dot" />
              <span class="alert-main"><strong>{{ row.itemName || row.itemCode }}</strong><small>{{ row.itemCode }} · {{ row.warehouseName || '-' }}</small></span>
              <span class="alert-qty"><strong>{{ quantity(row.quantity) }}</strong><small>下限 {{ quantity(row.minStock) }}</small></span>
            </button>
            <el-empty v-if="!lowStockLoading && !lowStocks.length" description="库存状态良好" :image-size="72" />
          </div>
          <el-button v-if="canViewStock" class="all-alerts" text type="danger" @click="router.push({ path: '/wms/stock', query: { lowStock: '1' } })">查看全部低库存物料</el-button>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup name="WmsDashboard">
import { getDashboardSummary, listRecentMovements } from '@/api/wms/dashboard'
import { listLowStock } from '@/api/wms/stock'
import auth from '@/plugins/auth'
import { dataOf, quantity, rowsOf } from '@/views/wms/utils'

const { proxy } = getCurrentInstance()
const router = useRouter()
const summaryLoading = ref(false)
const movementLoading = ref(false)
const lowStockLoading = ref(false)
const summary = reactive({ warehouseCount: 0, itemCount: 0, totalStock: 0, lowStockCount: 0, todayInbound: 0, todayOutbound: 0, pendingReceipt: 0, pendingShipment: 0 })
const recentMovements = ref([])
const lowStocks = ref([])
const canViewStock = computed(() => auth.hasPermi('wms:stock:list'))
const canViewReceipt = computed(() => auth.hasPermi('wms:receipt:list'))
const canViewShipment = computed(() => auth.hasPermi('wms:shipment:list'))
const todayText = computed(() => new Intl.DateTimeFormat('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' }).format(new Date()))
const summaryCards = computed(() => [
  { key: 'warehouse', label: '启用仓库', value: summary.warehouseCount, hint: '仓储网络节点', icon: 'OfficeBuilding', tone: 'blue' },
  { key: 'item', label: '物料总数', value: summary.itemCount, hint: '已维护物料档案', icon: 'Box', tone: 'violet' },
  { key: 'stock', label: '库存总量', value: summary.totalStock, hint: '当前账面库存', icon: 'Goods', tone: 'green' },
  { key: 'low', label: '低库存预警', value: summary.lowStockCount, hint: '需及时补货', icon: 'Warning', tone: 'orange' }
])

function changeQty(row) { return row.changeQty ?? row.changeQuantity ?? 0 }
function balanceQty(row) { return row.balanceQty ?? row.balanceQuantity ?? 0 }
function movementType(value) { return { INITIAL: '期初', RECEIPT: '入库', SHIPMENT: '出库', ADJUST_IN: '盘盈', ADJUST_OUT: '盘亏' }[value] || value || '-' }
async function loadSummary() { summaryLoading.value = true; try { Object.assign(summary, dataOf(await getDashboardSummary())) } finally { summaryLoading.value = false } }
async function loadMovements() { movementLoading.value = true; try { recentMovements.value = rowsOf(await listRecentMovements({ limit: 8 })).slice(0, 8) } finally { movementLoading.value = false } }
async function loadLowStocks() { lowStockLoading.value = true; try { lowStocks.value = rowsOf(await listLowStock({ pageNum: 1, pageSize: 6 })).slice(0, 6) } finally { lowStockLoading.value = false } }
function goLowStock(row) { if (canViewStock.value) router.push({ path: '/wms/stock', query: { lowStock: '1', itemId: row.itemId } }) }

loadSummary()
loadMovements()
loadLowStocks()
</script>

<style scoped lang="scss">
.dashboard-page { background: #f5f7fb; min-height: calc(100vh - 84px); color: #101828; }
.welcome-panel { position: relative; overflow: hidden; display: flex; align-items: center; justify-content: space-between; min-height: 148px; padding: 26px 34px; margin-bottom: 18px; color: #fff; border-radius: 14px; background: linear-gradient(120deg, #155eef 0%, #2970ff 50%, #53b1fd 100%); box-shadow: 0 10px 28px rgba(21, 94, 239, .18); &::after { content: ''; position: absolute; width: 260px; height: 260px; right: -80px; top: -110px; border-radius: 50%; border: 45px solid rgba(255,255,255,.08); } h1 { margin: 8px 0; font-size: 27px; letter-spacing: 1px; } p { margin: 0; color: rgba(255,255,255,.82); } }
.eyebrow { font-size: 11px; font-weight: 700; letter-spacing: 2px; color: #d1e9ff; }
.welcome-mark { z-index: 1; display: grid; place-items: center; width: 74px; height: 74px; border-radius: 20px; background: rgba(255,255,255,.14); border: 1px solid rgba(255,255,255,.2); font-size: 38px; }
.summary-grid { margin-bottom: 2px; }
.summary-card { position: relative; overflow: hidden; border: 0; margin-bottom: 16px; :deep(.el-card__body) { display: flex; align-items: center; gap: 16px; padding: 20px; } &::before { content: ''; position: absolute; inset: 0 auto 0 0; width: 4px; background: var(--tone); } }
.summary-icon { flex: none; display: grid; place-items: center; width: 50px; height: 50px; border-radius: 14px; color: var(--tone); background: var(--tone-soft); font-size: 25px; }
.summary-content { min-width: 0; display: flex; flex-direction: column; span { color: #667085; font-size: 13px; } strong { margin: 3px 0 1px; font-size: 25px; line-height: 1.15; } small { color: #98a2b3; } }
.tone-blue { --tone: #2e90fa; --tone-soft: #eff8ff; } .tone-violet { --tone: #875bf7; --tone-soft: #f4f3ff; } .tone-green { --tone: #12b76a; --tone-soft: #ecfdf3; } .tone-orange { --tone: #f79009; --tone-soft: #fffaeb; }
.operation-row, .detail-row { .el-col { margin-bottom: 16px; } }
.section-card { height: 100%; border: 1px solid #eaecf0; border-radius: 12px; }
.section-title { display: flex; align-items: center; justify-content: space-between; > div { display: flex; flex-direction: column; gap: 3px; } span { font-weight: 650; font-size: 16px; } small { color: #98a2b3; font-weight: 400; } }
.throughput { display: grid; grid-template-columns: 1fr 1px 1fr; align-items: center; min-height: 104px; }
.throughput-item { display: flex; align-items: center; justify-content: center; gap: 18px; > div:last-child { display: flex; flex-direction: column; } span { color: #667085; } strong { font-size: 26px; margin: 3px 0; } small { color: #98a2b3; } }
.throughput-icon { display: grid; place-items: center; width: 54px; height: 54px; border-radius: 50%; font-size: 26px; } .inbound .throughput-icon { color: #039855; background: #ecfdf3; } .outbound .throughput-icon { color: #1570ef; background: #eff8ff; }
.throughput-divider { height: 70px; background: #eaecf0; }
.pending-card :deep(.el-card__body) { padding: 8px 18px; }
.pending-item { appearance: none; width: 100%; display: grid; grid-template-columns: 40px 1fr auto 18px; gap: 10px; align-items: center; padding: 12px 0; border: 0; border-bottom: 1px solid #f2f4f7; background: none; color: inherit; text-align: left; cursor: pointer; &:last-child { border-bottom: 0; } &:hover .pending-name { color: #175cd3; } > strong { font-size: 20px; } }
.pending-symbol { display: grid; place-items: center; width: 38px; height: 38px; border-radius: 10px; } .pending-symbol.receipt { color: #039855; background: #ecfdf3; } .pending-symbol.shipment { color: #1570ef; background: #eff8ff; }
.pending-name { display: flex; flex-direction: column; gap: 2px; font-weight: 600; transition: color .2s; small { color: #98a2b3; font-weight: 400; } }
.table-sub { display: block; color: #98a2b3; margin-top: 2px; }
.increase { color: #039855; } .decrease { color: #d92d20; }
.alert-card :deep(.el-card__body) { padding: 6px 18px 14px; }
.alert-list { min-height: 270px; }
.alert-item { appearance: none; width: 100%; display: grid; grid-template-columns: 8px 1fr auto; gap: 10px; align-items: center; padding: 11px 0; border: 0; border-bottom: 1px solid #f2f4f7; background: none; color: inherit; text-align: left; cursor: pointer; &:hover:not(:disabled) .alert-main strong { color: #d92d20; } &:disabled { cursor: default; } }
.alert-dot { width: 7px; height: 7px; border-radius: 50%; background: #f04438; box-shadow: 0 0 0 4px #fef3f2; }
.alert-main, .alert-qty { display: flex; flex-direction: column; gap: 3px; small { color: #98a2b3; } } .alert-main { min-width: 0; strong, small { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; } } .alert-qty { text-align: right; strong { color: #d92d20; } }
.all-alerts { width: 100%; margin-top: 8px; }
@media (max-width: 768px) { .dashboard-page { padding: 12px; } .welcome-panel { padding: 22px; min-height: 128px; h1 { font-size: 22px; } } .welcome-mark { display: none; } .summary-card :deep(.el-card__body) { padding: 16px 12px; gap: 10px; } .summary-icon { width: 42px; height: 42px; font-size: 21px; } .summary-content strong { font-size: 21px; } .summary-content small { display: none; } .throughput { grid-template-columns: 1fr; gap: 18px; } .throughput-divider { display: none; } .throughput-item { justify-content: flex-start; } }
</style>
