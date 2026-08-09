<template>
  <div class="app-container wms-page">
    <div class="page-heading">
      <div>
        <h2>仓库管理</h2>
        <p>维护仓库基础信息，为库区、库位及库存业务提供范围边界。</p>
      </div>
      <el-tag type="primary" effect="light">基础资料</el-tag>
    </div>

    <el-card shadow="never" class="search-card">
      <el-form ref="queryRef" :model="queryParams" :inline="true" v-show="showSearch">
        <el-form-item label="仓库编码" prop="warehouseCode">
          <el-input v-model="queryParams.warehouseCode" placeholder="请输入仓库编码" clearable @keyup.enter="handleQuery" />
        </el-form-item>
        <el-form-item label="仓库名称" prop="warehouseName">
          <el-input v-model="queryParams.warehouseName" placeholder="请输入仓库名称" clearable @keyup.enter="handleQuery" />
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="queryParams.status" placeholder="全部状态" clearable style="width: 140px">
            <el-option v-for="item in normalStatusOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" icon="Search" @click="handleQuery">查询</el-button>
          <el-button icon="Refresh" @click="resetQuery">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never" class="table-card">
      <el-row :gutter="10" class="mb8">
        <el-col :span="1.5"><el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['wms:warehouse:add']">新增</el-button></el-col>
        <el-col :span="1.5"><el-button type="success" plain icon="Edit" :disabled="single" @click="handleUpdate()" v-hasPermi="['wms:warehouse:edit']">修改</el-button></el-col>
        <el-col :span="1.5"><el-button type="danger" plain icon="Delete" :disabled="multiple" @click="handleDelete()" v-hasPermi="['wms:warehouse:remove']">删除</el-button></el-col>
        <right-toolbar v-model:showSearch="showSearch" @queryTable="getList" />
      </el-row>

      <el-table v-loading="loading" :data="warehouseList" @selection-change="handleSelectionChange">
        <el-table-column type="selection" width="50" align="center" />
        <el-table-column label="仓库编码" prop="warehouseCode" min-width="120" show-overflow-tooltip />
        <el-table-column label="仓库名称" prop="warehouseName" min-width="150" show-overflow-tooltip />
        <el-table-column label="地址" prop="address" min-width="220" show-overflow-tooltip />
        <el-table-column label="负责人" prop="manager" width="110" show-overflow-tooltip />
        <el-table-column label="联系电话" prop="phone" width="140" />
        <el-table-column label="状态" prop="status" width="90" align="center">
          <template #default="scope"><el-tag :type="normalStatus(scope.row.status).type" effect="light">{{ normalStatus(scope.row.status).label }}</el-tag></template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right" align="center">
          <template #default="scope">
            <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['wms:warehouse:edit']">修改</el-button>
            <el-button link type="danger" icon="Delete" @click="handleDelete(scope.row)" v-hasPermi="['wms:warehouse:remove']">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      <pagination v-show="total > 0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />
    </el-card>

    <el-dialog v-model="open" :title="title" width="640px" append-to-body destroy-on-close>
      <el-form ref="warehouseRef" :model="form" :rules="rules" label-width="96px">
        <el-row :gutter="18">
          <el-col :xs="24" :sm="12"><el-form-item label="仓库编码" prop="warehouseCode"><el-input v-model="form.warehouseCode" placeholder="例如 WH-SH-01" maxlength="32" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="仓库名称" prop="warehouseName"><el-input v-model="form.warehouseName" placeholder="请输入仓库名称" maxlength="100" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="负责人" prop="manager"><el-input v-model="form.manager" placeholder="请输入负责人" maxlength="50" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="联系电话" prop="phone"><el-input v-model="form.phone" placeholder="请输入联系电话" maxlength="20" /></el-form-item></el-col>
          <el-col :span="24"><el-form-item label="仓库地址" prop="address"><el-input v-model="form.address" placeholder="请输入仓库地址" maxlength="255" /></el-form-item></el-col>
          <el-col :span="24"><el-form-item label="状态" prop="status"><el-radio-group v-model="form.status"><el-radio v-for="item in normalStatusOptions" :key="item.value" :value="item.value">{{ item.label }}</el-radio></el-radio-group></el-form-item></el-col>
        </el-row>
      </el-form>
      <template #footer><el-button @click="open = false">取消</el-button><el-button type="primary" :loading="submitting" @click="submitForm">保存</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="WmsWarehouse">
import { addWarehouse, delWarehouse, getWarehouse, listWarehouse, updateWarehouse } from '@/api/wms/warehouse'
import { dataOf, normalStatus, normalStatusOptions, rowsOf, totalOf } from '@/views/wms/utils'

const { proxy } = getCurrentInstance()
const loading = ref(false)
const submitting = ref(false)
const showSearch = ref(true)
const open = ref(false)
const title = ref('')
const warehouseList = ref([])
const total = ref(0)
const ids = ref([])
const single = computed(() => ids.value.length !== 1)
const multiple = computed(() => !ids.value.length)

const data = reactive({
  queryParams: { pageNum: 1, pageSize: 10, warehouseCode: undefined, warehouseName: undefined, status: undefined },
  form: {},
  rules: {
    warehouseCode: [{ required: true, message: '仓库编码不能为空', trigger: 'blur' }],
    warehouseName: [{ required: true, message: '仓库名称不能为空', trigger: 'blur' }],
    phone: [{ pattern: /^[0-9+\-()\s]{6,20}$/, message: '联系电话格式不正确', trigger: 'blur' }],
    status: [{ required: true, message: '请选择状态', trigger: 'change' }]
  }
})
const { queryParams, form, rules } = toRefs(data)

function reset() {
  form.value = { warehouseId: undefined, warehouseCode: '', warehouseName: '', address: '', manager: '', phone: '', status: '0' }
  proxy.resetForm('warehouseRef')
}
async function getList() {
  loading.value = true
  try {
    const response = await listWarehouse(queryParams.value)
    warehouseList.value = rowsOf(response)
    total.value = totalOf(response, warehouseList.value)
  } finally { loading.value = false }
}
function handleQuery() { queryParams.value.pageNum = 1; getList() }
function resetQuery() { proxy.resetForm('queryRef'); handleQuery() }
function handleSelectionChange(selection) { ids.value = selection.map(item => item.warehouseId) }
function handleAdd() { reset(); title.value = '新增仓库'; open.value = true }
async function handleUpdate(row) {
  reset()
  const warehouseId = row?.warehouseId ?? ids.value[0]
  const response = await getWarehouse(warehouseId)
  form.value = dataOf(response)
  title.value = '修改仓库'
  open.value = true
}
async function submitForm() {
  const valid = await proxy.$refs.warehouseRef.validate().catch(() => false)
  if (!valid) return
  submitting.value = true
  try {
    await (form.value.warehouseId ? updateWarehouse(form.value) : addWarehouse(form.value))
    proxy.$modal.msgSuccess(form.value.warehouseId ? '修改成功' : '新增成功')
    open.value = false
    getList()
  } finally { submitting.value = false }
}
async function handleDelete(row) {
  const warehouseIds = row?.warehouseId ?? ids.value.join(',')
  await proxy.$modal.confirm(`确认删除选中的仓库吗？关联库区或库存的仓库将无法删除。`)
  await delWarehouse(warehouseIds)
  proxy.$modal.msgSuccess('删除成功')
  getList()
}

getList()
</script>

<style scoped lang="scss">
.wms-page { background: #f6f8fb; min-height: calc(100vh - 84px); }
.page-heading { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; h2 { margin: 0 0 6px; font-size: 22px; color: #1d2939; } p { margin: 0; color: #667085; } }
.search-card { margin-bottom: 14px; :deep(.el-card__body) { padding-bottom: 2px; } }
.table-card { :deep(.el-card__body) { padding: 18px; } }
@media (max-width: 768px) { .page-heading { align-items: flex-start; gap: 12px; } .page-heading p { display: none; } }
</style>
