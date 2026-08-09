<template>
  <div class="app-container wms-page">
    <div class="page-heading">
      <div><h2>{{ config.pageTitle }}</h2><p>{{ config.description }}</p></div>
      <el-tag :type="config.tagType" effect="light">{{ config.businessLabel }}</el-tag>
    </div>

    <el-card shadow="never" class="search-card">
      <el-form ref="queryRef" :model="queryParams" :inline="true" v-show="showSearch">
        <el-form-item label="单据编号" :prop="config.noKey"><el-input v-model="queryParams[config.noKey]" placeholder="请输入单据编号" clearable @keyup.enter="handleQuery" /></el-form-item>
        <el-form-item label="业务类型" :prop="config.typeKey"><el-select v-model="queryParams[config.typeKey]" placeholder="全部类型" clearable style="width: 140px"><el-option v-for="item in config.types" :key="item.value" :label="item.label" :value="item.value" /></el-select></el-form-item>
        <el-form-item label="仓库" prop="warehouseId"><el-select v-model="queryParams.warehouseId" placeholder="全部仓库" clearable filterable style="width: 210px"><el-option v-for="item in warehouseOptions" :key="item.warehouseId" :label="optionText(item, 'warehouseCode', 'warehouseName')" :value="item.warehouseId" /></el-select></el-form-item>
        <el-form-item label="状态" prop="status"><el-select v-model="queryParams.status" placeholder="全部状态" clearable style="width: 130px"><el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" /></el-select></el-form-item>
        <el-form-item label="单据日期"><el-date-picker v-model="dateRange" type="daterange" value-format="YYYY-MM-DD" range-separator="至" start-placeholder="开始日期" end-placeholder="结束日期" style="width: 250px" /></el-form-item>
        <el-form-item><el-button type="primary" icon="Search" @click="handleQuery">查询</el-button><el-button icon="Refresh" @click="resetQuery">重置</el-button></el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never" class="table-card">
      <el-row :gutter="10" class="mb8">
        <el-col :span="1.5"><el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="[`${config.permission}:add`]">新增</el-button></el-col>
        <el-col :span="1.5"><el-button type="success" plain icon="Edit" :disabled="!canEditSelection" @click="handleUpdate()" v-hasPermi="[`${config.permission}:edit`]">修改</el-button></el-col>
        <el-col :span="1.5"><el-button type="danger" plain icon="Delete" :disabled="!canDeleteSelection" @click="handleDelete()" v-hasPermi="[`${config.permission}:remove`]">删除</el-button></el-col>
        <el-col :span="1.5"><el-button type="warning" plain icon="CircleCheck" :disabled="!canCompleteSelection" @click="handleComplete()" v-hasPermi="[`${config.permission}:complete`]">完成{{ config.shortLabel }}</el-button></el-col>
        <right-toolbar v-model:showSearch="showSearch" @queryTable="getList" />
      </el-row>

      <el-table v-loading="loading" :data="documentList" @selection-change="handleSelectionChange">
        <el-table-column type="selection" width="50" align="center" />
        <el-table-column label="单据编号" :prop="config.noKey" min-width="175" fixed="left"><template #default="scope"><el-button v-if="canView" link type="primary" @click="handleView(scope.row)">{{ scope.row[config.noKey] }}</el-button><span v-else>{{ scope.row[config.noKey] }}</span></template></el-table-column>
        <el-table-column label="类型" :prop="config.typeKey" width="105" align="center"><template #default="scope"><el-tag :type="config.tagType" effect="plain">{{ typeLabel(scope.row[config.typeKey]) }}</el-tag></template></el-table-column>
        <el-table-column label="仓库" prop="warehouseName" min-width="150" show-overflow-tooltip />
        <el-table-column :label="config.partnerLabel" :prop="config.partnerKey" min-width="160" show-overflow-tooltip />
        <el-table-column label="单据日期" :prop="config.dateKey" width="120"><template #default="scope">{{ parseDate(scope.row[config.dateKey]) }}</template></el-table-column>
        <el-table-column label="总数量" prop="totalQty" width="105" align="right"><template #default="scope"><strong>{{ quantity(scope.row.totalQty) }}</strong></template></el-table-column>
        <el-table-column label="状态" prop="status" width="100" align="center"><template #default="scope"><el-tag :type="documentStatus(scope.row.status).type" effect="light">{{ documentStatus(scope.row.status).label }}</el-tag></template></el-table-column>
        <el-table-column label="创建人" prop="createBy" width="105" show-overflow-tooltip />
        <el-table-column label="创建时间" prop="createTime" width="165"><template #default="scope">{{ proxy.parseTime(scope.row.createTime) || '-' }}</template></el-table-column>
        <el-table-column label="操作" width="230" fixed="right" align="center">
          <template #default="scope">
            <el-button link type="primary" icon="View" @click="handleView(scope.row)" v-hasPermi="[`${config.permission}:query`]">查看</el-button>
            <template v-if="isDraft(scope.row)">
              <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="[`${config.permission}:edit`]">修改</el-button>
              <el-button link type="success" icon="CircleCheck" @click="handleComplete(scope.row)" v-hasPermi="[`${config.permission}:complete`]">完成</el-button>
              <el-button link type="danger" icon="Delete" @click="handleDelete(scope.row)" v-hasPermi="[`${config.permission}:remove`]">删除</el-button>
            </template>
          </template>
        </el-table-column>
      </el-table>
      <pagination v-show="total > 0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />
    </el-card>

    <el-dialog v-model="open" :title="dialogTitle" width="min(1180px, 96vw)" top="4vh" append-to-body destroy-on-close :close-on-click-modal="false">
      <div v-loading="detailLoading">
        <el-alert v-if="readonly" :title="`当前单据状态：${documentStatus(form.status).label}，仅可查看`" type="info" :closable="false" show-icon class="status-alert" />
        <el-form ref="documentRef" :model="form" :rules="rules" label-width="94px" :disabled="readonly">
          <el-row :gutter="18">
            <el-col :xs="24" :md="8"><el-form-item label="单据编号" :prop="config.noKey"><el-input v-model="form[config.noKey]" placeholder="保存后自动生成" disabled /></el-form-item></el-col>
            <el-col :xs="24" :md="8"><el-form-item label="业务类型" :prop="config.typeKey"><el-select v-model="form[config.typeKey]" placeholder="请选择类型" style="width: 100%"><el-option v-for="item in config.types" :key="item.value" :label="item.label" :value="item.value" /></el-select></el-form-item></el-col>
            <el-col :xs="24" :md="8"><el-form-item label="单据日期" :prop="config.dateKey"><el-date-picker v-model="form[config.dateKey]" type="date" value-format="YYYY-MM-DD" placeholder="请选择日期" style="width: 100%" /></el-form-item></el-col>
            <el-col :xs="24" :md="12"><el-form-item label="仓库" prop="warehouseId"><el-select v-model="form.warehouseId" filterable placeholder="请选择仓库" style="width: 100%" @change="handleWarehouseChange"><el-option v-for="item in warehouseOptions" :key="item.warehouseId" :label="optionText(item, 'warehouseCode', 'warehouseName')" :value="item.warehouseId" /></el-select></el-form-item></el-col>
            <el-col :xs="24" :md="12"><el-form-item :label="config.partnerLabel" :prop="config.partnerKey"><el-input v-model="form[config.partnerKey]" :placeholder="`请输入${config.partnerLabel}`" maxlength="100" /></el-form-item></el-col>
          </el-row>

          <div class="line-heading"><div><strong>{{ config.shortLabel }}明细</strong><span>共 {{ form.lines?.length || 0 }} 行，计划 {{ quantity(plannedTotal) }}，{{ config.actualLabel }} {{ quantity(actualTotal) }}</span></div><el-button v-if="!readonly" type="primary" plain icon="Plus" @click="addLine">添加明细</el-button></div>
          <el-table :data="form.lines" border max-height="420" class="line-table" empty-text="请添加单据明细">
            <el-table-column type="index" label="#" width="48" align="center" fixed="left" />
            <el-table-column label="物料" min-width="220" fixed="left">
              <template #default="scope"><el-form-item :prop="`lines.${scope.$index}.itemId`" :rules="lineRules.itemId"><el-select v-model="scope.row.itemId" filterable placeholder="请选择物料" style="width: 100%"><el-option v-for="item in itemOptions" :key="item.itemId" :label="optionText(item, 'itemCode', 'itemName')" :value="item.itemId" /></el-select></el-form-item></template>
            </el-table-column>
            <el-table-column label="库位" min-width="190">
              <template #default="scope"><el-form-item :prop="`lines.${scope.$index}.locationId`" :rules="lineRules.locationId"><el-select v-model="scope.row.locationId" filterable placeholder="请选择库位" style="width: 100%"><el-option v-for="item in locationOptions" :key="item.locationId" :label="optionText(item, 'locationCode', 'locationName')" :value="item.locationId" /></el-select></el-form-item></template>
            </el-table-column>
            <el-table-column label="批次号" min-width="140"><template #default="scope"><el-form-item><el-input v-model="scope.row.batchNo" placeholder="可选" maxlength="64" /></el-form-item></template></el-table-column>
            <el-table-column v-if="kind === 'receipt'" label="生产日期" width="150"><template #default="scope"><el-form-item><el-date-picker v-model="scope.row.productionDate" type="date" value-format="YYYY-MM-DD" placeholder="选择日期" style="width: 100%" /></el-form-item></template></el-table-column>
            <el-table-column v-if="kind === 'receipt'" label="有效期至" width="150"><template #default="scope"><el-form-item><el-date-picker v-model="scope.row.expiryDate" type="date" value-format="YYYY-MM-DD" placeholder="选择日期" style="width: 100%" /></el-form-item></template></el-table-column>
            <el-table-column label="计划数量" width="145"><template #default="scope"><el-form-item :prop="`lines.${scope.$index}.plannedQty`" :rules="lineRules.plannedQty"><el-input-number v-model="scope.row.plannedQty" :min="0.0001" :precision="4" controls-position="right" style="width: 100%" /></el-form-item></template></el-table-column>
            <el-table-column :label="config.actualLabel" width="145"><template #default="scope"><el-form-item :prop="`lines.${scope.$index}.${config.actualKey}`" :rules="lineRules.actualQty"><el-input-number v-model="scope.row[config.actualKey]" :min="0" :precision="4" controls-position="right" style="width: 100%" /></el-form-item></template></el-table-column>
            <el-table-column v-if="!readonly" label="操作" width="70" fixed="right" align="center"><template #default="scope"><el-button link type="danger" icon="Delete" title="删除明细" @click="removeLine(scope.$index)" /></template></el-table-column>
          </el-table>
        </el-form>
      </div>
      <template #footer><el-button @click="open = false">{{ readonly ? '关闭' : '取消' }}</el-button><el-button v-if="!readonly" type="primary" :loading="submitting" @click="submitForm">保存草稿</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="WmsDocumentPage">
import { addReceipt, completeReceipt, delReceipt, getReceipt, listReceipt, updateReceipt } from '@/api/wms/receipt'
import { addShipment, completeShipment, delShipment, getShipment, listShipment, updateShipment } from '@/api/wms/shipment'
import { getItemOptions } from '@/api/wms/item'
import { getLocationOptions } from '@/api/wms/location'
import { getWarehouseOptions } from '@/api/wms/warehouse'
import auth from '@/plugins/auth'
import { dataOf, documentStatus, optionText, quantity, rowsOf, totalOf } from '@/views/wms/utils'

const props = defineProps({ kind: { type: String, required: true, validator: value => ['receipt', 'shipment'].includes(value) } })
const { proxy } = getCurrentInstance()
const statusOptions = [
  { value: 'DRAFT', label: '草稿' }, { value: 'COMPLETED', label: '已完成' }, { value: 'CANCELLED', label: '已取消' }
]
const configs = {
  receipt: {
    pageTitle: '入库管理', description: '创建并完成采购、退货等入库单据，完成后自动增加库存。', businessLabel: '入库业务', shortLabel: '入库单', tagType: 'success',
    idKey: 'receiptId', noKey: 'receiptNo', typeKey: 'receiptType', dateKey: 'receiptDate', partnerKey: 'supplierName', partnerLabel: '供应商', actualKey: 'receivedQty', actualLabel: '实收数量', permission: 'wms:receipt',
    types: [{ value: 'PURCHASE', label: '采购入库' }, { value: 'RETURN', label: '退货入库' }, { value: 'OTHER', label: '其他入库' }],
    api: { list: listReceipt, get: getReceipt, add: addReceipt, update: updateReceipt, remove: delReceipt, complete: completeReceipt }
  },
  shipment: {
    pageTitle: '出库管理', description: '创建并完成销售、退货等出库单据，完成前校验可用库存。', businessLabel: '出库业务', shortLabel: '出库单', tagType: 'primary',
    idKey: 'shipmentId', noKey: 'shipmentNo', typeKey: 'shipmentType', dateKey: 'shipmentDate', partnerKey: 'customerName', partnerLabel: '客户', actualKey: 'shippedQty', actualLabel: '实发数量', permission: 'wms:shipment',
    types: [{ value: 'SALE', label: '销售出库' }, { value: 'RETURN', label: '退货出库' }, { value: 'OTHER', label: '其他出库' }],
    api: { list: listShipment, get: getShipment, add: addShipment, update: updateShipment, remove: delShipment, complete: completeShipment }
  }
}
const config = computed(() => configs[props.kind])
const canView = computed(() => auth.hasPermi(`${config.value.permission}:query`))
const loading = ref(false)
const detailLoading = ref(false)
const submitting = ref(false)
const showSearch = ref(true)
const open = ref(false)
const readonly = ref(false)
const dialogTitle = ref('')
const documentList = ref([])
const selectedRows = ref([])
const warehouseOptions = ref([])
const itemOptions = ref([])
const locationOptions = ref([])
const total = ref(0)
const dateRange = ref([])
const queryParams = reactive({ pageNum: 1, pageSize: 10, receiptNo: undefined, shipmentNo: undefined, receiptType: undefined, shipmentType: undefined, warehouseId: undefined, status: undefined })
const form = ref({})
const rules = computed(() => ({
  [config.value.typeKey]: [{ required: true, message: '请选择业务类型', trigger: 'change' }],
  warehouseId: [{ required: true, message: '请选择仓库', trigger: 'change' }],
  [config.value.partnerKey]: [{ required: true, message: `请输入${config.value.partnerLabel}`, trigger: 'blur' }],
  [config.value.dateKey]: [{ required: true, message: '请选择单据日期', trigger: 'change' }]
}))
const lineRules = {
  itemId: [{ required: true, message: '请选择物料', trigger: 'change' }],
  locationId: [{ required: true, message: '请选择库位', trigger: 'change' }],
  plannedQty: [{ required: true, message: '请输入计划数量', trigger: 'change' }],
  actualQty: [{ required: true, message: '请输入实际数量', trigger: 'change' }]
}
const canEditSelection = computed(() => selectedRows.value.length === 1 && isDraft(selectedRows.value[0]))
const canDeleteSelection = computed(() => selectedRows.value.length > 0 && selectedRows.value.every(isDraft))
const canCompleteSelection = computed(() => selectedRows.value.length === 1 && isDraft(selectedRows.value[0]))
const plannedTotal = computed(() => (form.value.lines || []).reduce((sum, line) => sum + Number(line.plannedQty || 0), 0))
const actualTotal = computed(() => (form.value.lines || []).reduce((sum, line) => sum + Number(line[config.value.actualKey] || 0), 0))

function localToday() { const now = new Date(); const offset = now.getTimezoneOffset() * 60000; return new Date(now.getTime() - offset).toISOString().slice(0, 10) }
function parseDate(value) { return value ? String(value).slice(0, 10) : '-' }
function typeLabel(value) { return config.value.types.find(item => item.value === value)?.label || value || '-' }
function isDraft(row) { return row?.status === 'DRAFT' }
function newLine() { return { itemId: undefined, locationId: undefined, batchNo: '', ...(props.kind === 'receipt' ? { productionDate: undefined, expiryDate: undefined } : {}), plannedQty: 1, [config.value.actualKey]: 0 } }
function reset() {
  form.value = { [config.value.idKey]: undefined, [config.value.noKey]: '', [config.value.typeKey]: config.value.types[0].value, warehouseId: undefined, [config.value.partnerKey]: '', [config.value.dateKey]: localToday(), status: 'DRAFT', totalQty: 0, lines: [newLine()] }
  locationOptions.value = []
  proxy.resetForm('documentRef')
}
function normalizeDetail(response) {
  const detail = dataOf(response)
  const fallbackLines = detail.receiptLines || detail.shipmentLines || []
  return { ...detail, lines: Array.isArray(detail.lines) ? detail.lines : fallbackLines }
}
async function loadOptions() {
  const [warehouseRes, itemRes] = await Promise.all([getWarehouseOptions({ status: '0' }), getItemOptions({ status: '0' })])
  warehouseOptions.value = rowsOf(warehouseRes)
  itemOptions.value = rowsOf(itemRes)
}
async function handleWarehouseChange(warehouseId, preserveLocations = false) {
  if (!preserveLocations) (form.value.lines || []).forEach(line => { line.locationId = undefined })
  locationOptions.value = warehouseId ? rowsOf(await getLocationOptions({ warehouseId, status: '0' })) : []
}
function queryData() {
  const params = { ...queryParams }
  delete params[props.kind === 'receipt' ? 'shipmentNo' : 'receiptNo']
  delete params[props.kind === 'receipt' ? 'shipmentType' : 'receiptType']
  return proxy.addDateRange(params, dateRange.value)
}
async function getList() {
  loading.value = true
  try { const response = await config.value.api.list(queryData()); documentList.value = rowsOf(response); total.value = totalOf(response, documentList.value) }
  finally { loading.value = false }
}
function handleQuery() { queryParams.pageNum = 1; getList() }
function resetQuery() { proxy.resetForm('queryRef'); dateRange.value = []; handleQuery() }
function handleSelectionChange(selection) { selectedRows.value = selection }
function handleAdd() { reset(); readonly.value = false; dialogTitle.value = `新增${config.value.shortLabel}`; open.value = true }
async function loadDetail(row, viewOnly) {
  reset()
  readonly.value = viewOnly
  dialogTitle.value = `${viewOnly ? '查看' : '修改'}${config.value.shortLabel}`
  detailLoading.value = true
  open.value = true
  try {
    const id = row?.[config.value.idKey] ?? selectedRows.value[0]?.[config.value.idKey]
    form.value = normalizeDetail(await config.value.api.get(id))
    if (!Array.isArray(form.value.lines)) form.value.lines = []
    await handleWarehouseChange(form.value.warehouseId, true)
  } finally { detailLoading.value = false }
}
function handleView(row) { loadDetail(row, true) }
function handleUpdate(row) { const target = row || selectedRows.value[0]; if (!isDraft(target)) return proxy.$modal.msgWarning('仅草稿单据允许修改'); loadDetail(target, false) }
function addLine() { form.value.lines.push(newLine()) }
function removeLine(index) { form.value.lines.splice(index, 1) }
async function submitForm() {
  if (!form.value.lines?.length) return proxy.$modal.msgWarning('请至少添加一条单据明细')
  const valid = await proxy.$refs.documentRef.validate().catch(() => false)
  if (!valid) return
  if (props.kind === 'receipt' && form.value.lines.some(line => line.productionDate && line.expiryDate && line.expiryDate < line.productionDate)) return proxy.$modal.msgWarning('有效期不能早于生产日期')
  submitting.value = true
  try {
    form.value.totalQty = actualTotal.value
    await (form.value[config.value.idKey] ? config.value.api.update(form.value) : config.value.api.add(form.value))
    proxy.$modal.msgSuccess(form.value[config.value.idKey] ? '修改成功' : '新增成功')
    open.value = false
    getList()
  } finally { submitting.value = false }
}
async function handleDelete(row) {
  const targets = row ? [row] : selectedRows.value
  if (!targets.length || targets.some(item => !isDraft(item))) return proxy.$modal.msgWarning('仅草稿单据允许删除')
  const ids = targets.map(item => item[config.value.idKey]).join(',')
  await proxy.$modal.confirm(`确认删除选中的${config.value.shortLabel}吗？`)
  await config.value.api.remove(ids)
  proxy.$modal.msgSuccess('删除成功')
  getList()
}
async function handleComplete(row) {
  const target = row || selectedRows.value[0]
  if (!isDraft(target)) return proxy.$modal.msgWarning('仅草稿单据允许完成')
  await proxy.$modal.confirm(`完成后将立即${props.kind === 'receipt' ? '增加' : '扣减'}库存且不可修改，确认完成单据 ${target[config.value.noKey]} 吗？`)
  await config.value.api.complete(target[config.value.idKey])
  proxy.$modal.msgSuccess(`${config.value.shortLabel}已完成`)
  getList()
}

loadOptions()
getList()
</script>

<style scoped lang="scss">
.wms-page { background: #f6f8fb; min-height: calc(100vh - 84px); }
.page-heading { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; h2 { margin: 0 0 6px; font-size: 22px; color: #1d2939; } p { margin: 0; color: #667085; } }
.search-card { margin-bottom: 14px; :deep(.el-card__body) { padding-bottom: 2px; } }
.table-card :deep(.el-card__body) { padding: 18px; }
.status-alert { margin-bottom: 18px; }
.line-heading { display: flex; align-items: center; justify-content: space-between; margin: 4px 0 12px; padding-top: 14px; border-top: 1px solid #eaecf0; > div { display: flex; flex-direction: column; gap: 4px; } strong { font-size: 16px; color: #344054; } span { color: #98a2b3; font-size: 12px; } }
.line-table :deep(.el-form-item) { margin: 8px 0; }
.line-table :deep(.el-form-item__error) { position: static; line-height: 16px; }
@media (max-width: 768px) { .page-heading { align-items: flex-start; gap: 12px; } .page-heading p { display: none; } }
</style>
