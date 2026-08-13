<template>
  <div class="app-container wms-page">
    <div class="page-heading">
      <div><h2>库区管理</h2><p>按用途划分仓库作业区域，便于库位组织和库存管理。</p></div>
      <el-tag type="primary" effect="light">基础资料</el-tag>
    </div>

    <el-card shadow="never" class="search-card">
      <el-form ref="queryRef" :model="queryParams" :inline="true" v-show="showSearch">
        <el-form-item label="所属仓库" prop="warehouseId">
          <el-select v-model="queryParams.warehouseId" placeholder="全部仓库" clearable filterable style="width: 220px">
            <el-option v-for="item in warehouseOptions" :key="item.warehouseId" :label="optionText(item, 'warehouseCode', 'warehouseName')" :value="item.warehouseId" />
          </el-select>
        </el-form-item>
        <el-form-item label="库区编码" prop="areaCode"><el-input v-model="queryParams.areaCode" placeholder="请输入库区编码" clearable @keyup.enter="handleQuery" /></el-form-item>
        <el-form-item label="库区名称" prop="areaName"><el-input v-model="queryParams.areaName" placeholder="请输入库区名称" clearable @keyup.enter="handleQuery" /></el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="queryParams.status" placeholder="全部状态" clearable style="width: 130px"><el-option v-for="item in normalStatusOptions" :key="item.value" :label="item.label" :value="item.value" /></el-select>
        </el-form-item>
        <el-form-item><el-button type="primary" icon="Search" @click="handleQuery">查询</el-button><el-button icon="Refresh" @click="resetQuery">重置</el-button></el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never" class="table-card">
      <el-row :gutter="10" class="mb8">
        <el-col :span="1.5"><el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['wms:area:add']">新增</el-button></el-col>
        <el-col :span="1.5"><el-button type="success" plain icon="Edit" :disabled="single" @click="handleUpdate()" v-hasPermi="['wms:area:edit']">修改</el-button></el-col>
        <el-col :span="1.5"><el-button type="danger" plain icon="Delete" :disabled="multiple" @click="handleDelete()" v-hasPermi="['wms:area:remove']">删除</el-button></el-col>
        <el-col :span="1.5"><el-button type="warning" plain icon="Download" @click="handleExport" v-hasPermi="['wms:area:export']">导出</el-button></el-col>
        <right-toolbar v-model:showSearch="showSearch" @queryTable="getList" />
      </el-row>
      <el-table v-loading="loading" :data="areaList" @selection-change="handleSelectionChange">
        <el-table-column type="selection" width="50" align="center" />
        <el-table-column label="仓库" min-width="170" show-overflow-tooltip><template #default="scope">{{ scope.row.warehouseName || warehouseLabel(scope.row.warehouseId) }}</template></el-table-column>
        <el-table-column label="库区编码" prop="areaCode" min-width="120" />
        <el-table-column label="库区名称" prop="areaName" min-width="140" show-overflow-tooltip />
        <el-table-column label="库区类型" prop="areaType" width="110" align="center"><template #default="scope">{{ areaTypeLabel(scope.row.areaType) }}</template></el-table-column>
        <el-table-column label="状态" width="90" align="center"><template #default="scope"><el-tag :type="normalStatus(scope.row.status).type" effect="light">{{ normalStatus(scope.row.status).label }}</el-tag></template></el-table-column>
        <el-table-column label="操作" width="150" fixed="right" align="center"><template #default="scope"><el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['wms:area:edit']">修改</el-button><el-button link type="danger" icon="Delete" @click="handleDelete(scope.row)" v-hasPermi="['wms:area:remove']">删除</el-button></template></el-table-column>
      </el-table>
      <pagination v-show="total > 0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />
    </el-card>

    <el-dialog v-model="open" :title="title" width="600px" append-to-body destroy-on-close>
      <el-form ref="areaRef" :model="form" :rules="rules" label-width="96px">
        <el-row :gutter="18">
          <el-col :span="24"><el-form-item label="所属仓库" prop="warehouseId"><el-select v-model="form.warehouseId" filterable placeholder="请选择仓库" style="width: 100%"><el-option v-for="item in warehouseOptions" :key="item.warehouseId" :label="optionText(item, 'warehouseCode', 'warehouseName')" :value="item.warehouseId" /></el-select></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="库区编码" prop="areaCode"><el-input v-model="form.areaCode" placeholder="例如 A01" maxlength="32" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="库区名称" prop="areaName"><el-input v-model="form.areaName" placeholder="请输入库区名称" maxlength="100" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="库区类型" prop="areaType"><el-select v-model="form.areaType" placeholder="请选择类型" style="width: 100%"><el-option v-for="item in areaTypes" :key="item.value" :label="item.label" :value="item.value" /></el-select></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="状态" prop="status"><el-radio-group v-model="form.status"><el-radio v-for="item in normalStatusOptions" :key="item.value" :value="item.value">{{ item.label }}</el-radio></el-radio-group></el-form-item></el-col>
        </el-row>
      </el-form>
      <template #footer><el-button @click="open = false">取消</el-button><el-button type="primary" :loading="submitting" @click="submitForm">保存</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="WmsArea">
import { addArea, delArea, getArea, listArea, updateArea } from '@/api/wms/area'
import { getWarehouseOptions } from '@/api/wms/warehouse'
import { dataOf, normalStatus, normalStatusOptions, optionText, rowsOf, totalOf } from '@/views/wms/utils'

const { proxy } = getCurrentInstance()
const areaTypes = [
  { value: 'RECEIVING', label: '收货区' }, { value: 'STORAGE', label: '存储区' },
  { value: 'PICKING', label: '拣货区' }, { value: 'SHIPPING', label: '发货区' },
  { value: 'RETURN', label: '退货区' }
]
const loading = ref(false)
const submitting = ref(false)
const showSearch = ref(true)
const open = ref(false)
const title = ref('')
const areaList = ref([])
const warehouseOptions = ref([])
const total = ref(0)
const ids = ref([])
const single = computed(() => ids.value.length !== 1)
const multiple = computed(() => !ids.value.length)
const data = reactive({
  queryParams: { pageNum: 1, pageSize: 10, warehouseId: undefined, areaCode: undefined, areaName: undefined, status: undefined },
  form: {},
  rules: {
    warehouseId: [{ required: true, message: '请选择所属仓库', trigger: 'change' }],
    areaCode: [{ required: true, message: '库区编码不能为空', trigger: 'blur' }],
    areaName: [{ required: true, message: '库区名称不能为空', trigger: 'blur' }],
    areaType: [{ required: true, message: '请选择库区类型', trigger: 'change' }],
    status: [{ required: true, message: '请选择状态', trigger: 'change' }]
  }
})
const { queryParams, form, rules } = toRefs(data)

function areaTypeLabel(value) { return areaTypes.find(item => item.value === value)?.label || value || '-' }
function warehouseLabel(id) { const item = warehouseOptions.value.find(option => String(option.warehouseId) === String(id)); return item ? optionText(item, 'warehouseCode', 'warehouseName') : '-' }
function reset() { form.value = { areaId: undefined, warehouseId: undefined, areaCode: '', areaName: '', areaType: 'STORAGE', status: '0' }; proxy.resetForm('areaRef') }
async function loadWarehouses() { warehouseOptions.value = rowsOf(await getWarehouseOptions({ status: '0' })) }
async function getList() { loading.value = true; try { const response = await listArea(queryParams.value); areaList.value = rowsOf(response); total.value = totalOf(response, areaList.value) } finally { loading.value = false } }
function handleQuery() { queryParams.value.pageNum = 1; getList() }
function resetQuery() { proxy.resetForm('queryRef'); handleQuery() }
function handleExport() { proxy.download('wms/area/export', queryParams.value, `库区数据_${Date.now()}.xlsx`) }
function handleSelectionChange(selection) { ids.value = selection.map(item => item.areaId) }
function handleAdd() { reset(); title.value = '新增库区'; open.value = true }
async function handleUpdate(row) { reset(); const response = await getArea(row?.areaId ?? ids.value[0]); form.value = dataOf(response); title.value = '修改库区'; open.value = true }
async function submitForm() { const valid = await proxy.$refs.areaRef.validate().catch(() => false); if (!valid) return; submitting.value = true; try { await (form.value.areaId ? updateArea(form.value) : addArea(form.value)); proxy.$modal.msgSuccess(form.value.areaId ? '修改成功' : '新增成功'); open.value = false; getList() } finally { submitting.value = false } }
async function handleDelete(row) { const areaIds = row?.areaId ?? ids.value.join(','); await proxy.$modal.confirm('确认删除选中的库区吗？已关联库位的库区将无法删除。'); await delArea(areaIds); proxy.$modal.msgSuccess('删除成功'); getList() }

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
