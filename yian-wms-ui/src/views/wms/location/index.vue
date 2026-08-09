<template>
  <div class="app-container wms-page">
    <div class="page-heading">
      <div><h2>库位管理</h2><p>维护可实际存放库存的库位及容量，支持按仓库、库区快速定位。</p></div>
      <el-tag type="primary" effect="light">基础资料</el-tag>
    </div>

    <el-card shadow="never" class="search-card">
      <el-form ref="queryRef" :model="queryParams" :inline="true" v-show="showSearch">
        <el-form-item label="所属仓库" prop="warehouseId">
          <el-select v-model="queryParams.warehouseId" placeholder="全部仓库" clearable filterable style="width: 210px" @change="handleQueryWarehouseChange">
            <el-option v-for="item in warehouseOptions" :key="item.warehouseId" :label="optionText(item, 'warehouseCode', 'warehouseName')" :value="item.warehouseId" />
          </el-select>
        </el-form-item>
        <el-form-item label="所属库区" prop="areaId"><el-select v-model="queryParams.areaId" placeholder="全部库区" clearable filterable style="width: 190px"><el-option v-for="item in queryAreaOptions" :key="item.areaId" :label="optionText(item, 'areaCode', 'areaName')" :value="item.areaId" /></el-select></el-form-item>
        <el-form-item label="库位编码" prop="locationCode"><el-input v-model="queryParams.locationCode" placeholder="请输入库位编码" clearable @keyup.enter="handleQuery" /></el-form-item>
        <el-form-item label="库位名称" prop="locationName"><el-input v-model="queryParams.locationName" placeholder="请输入库位名称" clearable @keyup.enter="handleQuery" /></el-form-item>
        <el-form-item><el-button type="primary" icon="Search" @click="handleQuery">查询</el-button><el-button icon="Refresh" @click="resetQuery">重置</el-button></el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never" class="table-card">
      <el-row :gutter="10" class="mb8">
        <el-col :span="1.5"><el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['wms:location:add']">新增</el-button></el-col>
        <el-col :span="1.5"><el-button type="success" plain icon="Edit" :disabled="single" @click="handleUpdate()" v-hasPermi="['wms:location:edit']">修改</el-button></el-col>
        <el-col :span="1.5"><el-button type="danger" plain icon="Delete" :disabled="multiple" @click="handleDelete()" v-hasPermi="['wms:location:remove']">删除</el-button></el-col>
        <right-toolbar v-model:showSearch="showSearch" @queryTable="getList" />
      </el-row>
      <el-table v-loading="loading" :data="locationList" @selection-change="handleSelectionChange">
        <el-table-column type="selection" width="50" align="center" />
        <el-table-column label="仓库" prop="warehouseName" min-width="140" show-overflow-tooltip />
        <el-table-column label="库区" prop="areaName" min-width="120" show-overflow-tooltip />
        <el-table-column label="库位编码" prop="locationCode" min-width="125" />
        <el-table-column label="库位名称" prop="locationName" min-width="140" show-overflow-tooltip />
        <el-table-column label="类型" width="90" align="center"><template #default="scope"><el-tag :type="locationType(scope.row.locationType).tag" effect="plain">{{ locationType(scope.row.locationType).label }}</el-tag></template></el-table-column>
        <el-table-column label="容量" prop="capacityQty" width="110" align="right"><template #default="scope">{{ quantity(scope.row.capacityQty) }}</template></el-table-column>
        <el-table-column label="状态" width="90" align="center"><template #default="scope"><el-tag :type="normalStatus(scope.row.status).type" effect="light">{{ normalStatus(scope.row.status).label }}</el-tag></template></el-table-column>
        <el-table-column label="操作" width="150" fixed="right" align="center"><template #default="scope"><el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['wms:location:edit']">修改</el-button><el-button link type="danger" icon="Delete" @click="handleDelete(scope.row)" v-hasPermi="['wms:location:remove']">删除</el-button></template></el-table-column>
      </el-table>
      <pagination v-show="total > 0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />
    </el-card>

    <el-dialog v-model="open" :title="title" width="660px" append-to-body destroy-on-close>
      <el-form ref="locationRef" :model="form" :rules="rules" label-width="96px">
        <el-row :gutter="18">
          <el-col :xs="24" :sm="12"><el-form-item label="所属仓库" prop="warehouseId"><el-select v-model="form.warehouseId" filterable placeholder="请选择仓库" style="width: 100%" @change="handleFormWarehouseChange"><el-option v-for="item in warehouseOptions" :key="item.warehouseId" :label="optionText(item, 'warehouseCode', 'warehouseName')" :value="item.warehouseId" /></el-select></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="所属库区" prop="areaId"><el-select v-model="form.areaId" filterable placeholder="请选择库区" style="width: 100%"><el-option v-for="item in formAreaOptions" :key="item.areaId" :label="optionText(item, 'areaCode', 'areaName')" :value="item.areaId" /></el-select></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="库位编码" prop="locationCode"><el-input v-model="form.locationCode" placeholder="例如 A01-01-01" maxlength="32" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="库位名称" prop="locationName"><el-input v-model="form.locationName" placeholder="请输入库位名称" maxlength="100" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="库位类型" prop="locationType"><el-select v-model="form.locationType" style="width: 100%"><el-option v-for="item in locationTypes" :key="item.value" :label="item.label" :value="item.value" /></el-select></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="容量" prop="capacityQty"><el-input-number v-model="form.capacityQty" :min="0" :precision="4" :step="1" controls-position="right" style="width: 100%" /></el-form-item></el-col>
          <el-col :span="24"><el-form-item label="状态" prop="status"><el-radio-group v-model="form.status"><el-radio v-for="item in normalStatusOptions" :key="item.value" :value="item.value">{{ item.label }}</el-radio></el-radio-group></el-form-item></el-col>
        </el-row>
      </el-form>
      <template #footer><el-button @click="open = false">取消</el-button><el-button type="primary" :loading="submitting" @click="submitForm">保存</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="WmsLocation">
import { listArea } from '@/api/wms/area'
import { addLocation, delLocation, getLocation, listLocation, updateLocation } from '@/api/wms/location'
import { getWarehouseOptions } from '@/api/wms/warehouse'
import { dataOf, normalStatus, normalStatusOptions, optionText, quantity, rowsOf, totalOf } from '@/views/wms/utils'

const { proxy } = getCurrentInstance()
const locationTypes = [
  { value: 'NORMAL', label: '普通', tag: '' },
  { value: 'FROZEN', label: '冷冻', tag: 'primary' },
  { value: 'DEFECTIVE', label: '不良品', tag: 'danger' }
]
const loading = ref(false)
const submitting = ref(false)
const showSearch = ref(true)
const open = ref(false)
const title = ref('')
const locationList = ref([])
const warehouseOptions = ref([])
const queryAreaOptions = ref([])
const formAreaOptions = ref([])
const total = ref(0)
const ids = ref([])
const single = computed(() => ids.value.length !== 1)
const multiple = computed(() => !ids.value.length)
const data = reactive({
  queryParams: { pageNum: 1, pageSize: 10, warehouseId: undefined, areaId: undefined, locationCode: undefined, locationName: undefined },
  form: {},
  rules: {
    warehouseId: [{ required: true, message: '请选择所属仓库', trigger: 'change' }],
    areaId: [{ required: true, message: '请选择所属库区', trigger: 'change' }],
    locationCode: [{ required: true, message: '库位编码不能为空', trigger: 'blur' }],
    locationName: [{ required: true, message: '库位名称不能为空', trigger: 'blur' }],
    locationType: [{ required: true, message: '请选择库位类型', trigger: 'change' }],
    capacityQty: [{ required: true, message: '请输入容量', trigger: 'change' }],
    status: [{ required: true, message: '请选择状态', trigger: 'change' }]
  }
})
const { queryParams, form, rules } = toRefs(data)

function locationType(value) { return locationTypes.find(item => item.value === value) || { label: value || '-', tag: 'info' } }
async function loadAreas(warehouseId) { if (!warehouseId) return []; return rowsOf(await listArea({ pageNum: 1, pageSize: 1000, warehouseId, status: '0' })) }
async function handleQueryWarehouseChange(value) { queryParams.value.areaId = undefined; queryAreaOptions.value = await loadAreas(value) }
async function handleFormWarehouseChange(value, preserveArea = false) { if (!preserveArea) form.value.areaId = undefined; formAreaOptions.value = await loadAreas(value) }
function reset() { form.value = { locationId: undefined, warehouseId: undefined, areaId: undefined, locationCode: '', locationName: '', locationType: 'NORMAL', capacityQty: 0, status: '0' }; formAreaOptions.value = []; proxy.resetForm('locationRef') }
async function loadWarehouses() { warehouseOptions.value = rowsOf(await getWarehouseOptions({ status: '0' })) }
async function getList() { loading.value = true; try { const response = await listLocation(queryParams.value); locationList.value = rowsOf(response); total.value = totalOf(response, locationList.value) } finally { loading.value = false } }
function handleQuery() { queryParams.value.pageNum = 1; getList() }
function resetQuery() { proxy.resetForm('queryRef'); queryAreaOptions.value = []; handleQuery() }
function handleSelectionChange(selection) { ids.value = selection.map(item => item.locationId) }
function handleAdd() { reset(); title.value = '新增库位'; open.value = true }
async function handleUpdate(row) { reset(); const response = await getLocation(row?.locationId ?? ids.value[0]); form.value = dataOf(response); await handleFormWarehouseChange(form.value.warehouseId, true); title.value = '修改库位'; open.value = true }
async function submitForm() { const valid = await proxy.$refs.locationRef.validate().catch(() => false); if (!valid) return; submitting.value = true; try { await (form.value.locationId ? updateLocation(form.value) : addLocation(form.value)); proxy.$modal.msgSuccess(form.value.locationId ? '修改成功' : '新增成功'); open.value = false; getList() } finally { submitting.value = false } }
async function handleDelete(row) { const locationIds = row?.locationId ?? ids.value.join(','); await proxy.$modal.confirm('确认删除选中的库位吗？存在库存的库位将无法删除。'); await delLocation(locationIds); proxy.$modal.msgSuccess('删除成功'); getList() }

loadWarehouses()
getList()
</script>

<style scoped lang="scss">
.wms-page { background: #f6f8fb; min-height: calc(100vh - 84px); }
.page-heading { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; h2 { margin: 0 0 6px; font-size: 22px; color: #1d2939; } p { margin: 0; color: #667085; } }
.search-card { margin-bottom: 14px; :deep(.el-card__body) { padding-bottom: 2px; } }
.table-card :deep(.el-card__body) { padding: 18px; }
@media (max-width: 768px) { .page-heading { align-items: flex-start; gap: 12px; } .page-heading p { display: none; } }
</style>
