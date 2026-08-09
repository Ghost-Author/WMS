<template>
  <div class="app-container wms-page">
    <div class="page-heading">
      <div><h2>物料管理</h2><p>统一维护物料编码、规格、条码与安全库存上下限。</p></div>
      <el-tag type="primary" effect="light">基础资料</el-tag>
    </div>

    <el-card shadow="never" class="search-card">
      <el-form ref="queryRef" :model="queryParams" :inline="true" v-show="showSearch">
        <el-form-item label="物料编码" prop="itemCode"><el-input v-model="queryParams.itemCode" placeholder="请输入物料编码" clearable @keyup.enter="handleQuery" /></el-form-item>
        <el-form-item label="物料名称" prop="itemName"><el-input v-model="queryParams.itemName" placeholder="请输入物料名称" clearable @keyup.enter="handleQuery" /></el-form-item>
        <el-form-item label="分类" prop="category"><el-input v-model="queryParams.category" placeholder="请输入分类" clearable @keyup.enter="handleQuery" /></el-form-item>
        <el-form-item label="状态" prop="status"><el-select v-model="queryParams.status" placeholder="全部状态" clearable style="width: 130px"><el-option v-for="item in normalStatusOptions" :key="item.value" :label="item.label" :value="item.value" /></el-select></el-form-item>
        <el-form-item><el-button type="primary" icon="Search" @click="handleQuery">查询</el-button><el-button icon="Refresh" @click="resetQuery">重置</el-button></el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never" class="table-card">
      <el-row :gutter="10" class="mb8">
        <el-col :span="1.5"><el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['wms:item:add']">新增</el-button></el-col>
        <el-col :span="1.5"><el-button type="success" plain icon="Edit" :disabled="single" @click="handleUpdate()" v-hasPermi="['wms:item:edit']">修改</el-button></el-col>
        <el-col :span="1.5"><el-button type="danger" plain icon="Delete" :disabled="multiple" @click="handleDelete()" v-hasPermi="['wms:item:remove']">删除</el-button></el-col>
        <right-toolbar v-model:showSearch="showSearch" @queryTable="getList" />
      </el-row>
      <el-table v-loading="loading" :data="itemList" @selection-change="handleSelectionChange">
        <el-table-column type="selection" width="50" align="center" />
        <el-table-column label="物料编码" prop="itemCode" min-width="130" fixed="left" />
        <el-table-column label="物料名称" prop="itemName" min-width="160" show-overflow-tooltip />
        <el-table-column label="分类" prop="category" width="120" show-overflow-tooltip />
        <el-table-column label="规格型号" prop="specification" min-width="150" show-overflow-tooltip />
        <el-table-column label="单位" prop="unit" width="80" align="center" />
        <el-table-column label="条码" prop="barcode" min-width="150" show-overflow-tooltip />
        <el-table-column label="最低库存" prop="minStock" width="110" align="right"><template #default="scope">{{ quantity(scope.row.minStock) }}</template></el-table-column>
        <el-table-column label="最高库存" prop="maxStock" width="110" align="right"><template #default="scope">{{ quantity(scope.row.maxStock) }}</template></el-table-column>
        <el-table-column label="状态" width="90" align="center"><template #default="scope"><el-tag :type="normalStatus(scope.row.status).type" effect="light">{{ normalStatus(scope.row.status).label }}</el-tag></template></el-table-column>
        <el-table-column label="操作" width="150" fixed="right" align="center"><template #default="scope"><el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['wms:item:edit']">修改</el-button><el-button link type="danger" icon="Delete" @click="handleDelete(scope.row)" v-hasPermi="['wms:item:remove']">删除</el-button></template></el-table-column>
      </el-table>
      <pagination v-show="total > 0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />
    </el-card>

    <el-dialog v-model="open" :title="title" width="720px" append-to-body destroy-on-close>
      <el-form ref="itemRef" :model="form" :rules="rules" label-width="96px">
        <el-row :gutter="18">
          <el-col :xs="24" :sm="12"><el-form-item label="物料编码" prop="itemCode"><el-input v-model="form.itemCode" placeholder="请输入物料编码" maxlength="32" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="物料名称" prop="itemName"><el-input v-model="form.itemName" placeholder="请输入物料名称" maxlength="100" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="物料分类" prop="category"><el-input v-model="form.category" placeholder="例如 原材料" maxlength="50" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="规格型号" prop="specification"><el-input v-model="form.specification" placeholder="请输入规格型号" maxlength="100" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="计量单位" prop="unit"><el-input v-model="form.unit" placeholder="例如 件、箱、kg" maxlength="20" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="条码" prop="barcode"><el-input v-model="form.barcode" placeholder="请输入商品条码" maxlength="100" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="最低库存" prop="minStock"><el-input-number v-model="form.minStock" :min="0" :precision="4" controls-position="right" style="width: 100%" /></el-form-item></el-col>
          <el-col :xs="24" :sm="12"><el-form-item label="最高库存" prop="maxStock"><el-input-number v-model="form.maxStock" :min="0" :precision="4" controls-position="right" style="width: 100%" /></el-form-item></el-col>
          <el-col :span="24"><el-form-item label="状态" prop="status"><el-radio-group v-model="form.status"><el-radio v-for="item in normalStatusOptions" :key="item.value" :value="item.value">{{ item.label }}</el-radio></el-radio-group></el-form-item></el-col>
        </el-row>
      </el-form>
      <template #footer><el-button @click="open = false">取消</el-button><el-button type="primary" :loading="submitting" @click="submitForm">保存</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="WmsItem">
import { addItem, delItem, getItem, listItem, updateItem } from '@/api/wms/item'
import { dataOf, normalStatus, normalStatusOptions, quantity, rowsOf, totalOf } from '@/views/wms/utils'

const { proxy } = getCurrentInstance()
const loading = ref(false)
const submitting = ref(false)
const showSearch = ref(true)
const open = ref(false)
const title = ref('')
const itemList = ref([])
const total = ref(0)
const ids = ref([])
const single = computed(() => ids.value.length !== 1)
const multiple = computed(() => !ids.value.length)
const validateMaxStock = (_rule, value, callback) => {
  if (value != null && form.value.minStock != null && Number(value) < Number(form.value.minStock)) callback(new Error('最高库存不能小于最低库存'))
  else callback()
}
const data = reactive({
  queryParams: { pageNum: 1, pageSize: 10, itemCode: undefined, itemName: undefined, category: undefined, status: undefined },
  form: {},
  rules: {
    itemCode: [{ required: true, message: '物料编码不能为空', trigger: 'blur' }],
    itemName: [{ required: true, message: '物料名称不能为空', trigger: 'blur' }],
    unit: [{ required: true, message: '计量单位不能为空', trigger: 'blur' }],
    minStock: [{ required: true, message: '请输入最低库存', trigger: 'change' }],
    maxStock: [{ validator: validateMaxStock, trigger: 'change' }],
    status: [{ required: true, message: '请选择状态', trigger: 'change' }]
  }
})
const { queryParams, form, rules } = toRefs(data)

function reset() { form.value = { itemId: undefined, itemCode: '', itemName: '', category: '', specification: '', unit: '', barcode: '', minStock: 0, maxStock: null, status: '0' }; proxy.resetForm('itemRef') }
async function getList() { loading.value = true; try { const response = await listItem(queryParams.value); itemList.value = rowsOf(response); total.value = totalOf(response, itemList.value) } finally { loading.value = false } }
function handleQuery() { queryParams.value.pageNum = 1; getList() }
function resetQuery() { proxy.resetForm('queryRef'); handleQuery() }
function handleSelectionChange(selection) { ids.value = selection.map(item => item.itemId) }
function handleAdd() { reset(); title.value = '新增物料'; open.value = true }
async function handleUpdate(row) { reset(); const response = await getItem(row?.itemId ?? ids.value[0]); form.value = dataOf(response); title.value = '修改物料'; open.value = true }
async function submitForm() { const valid = await proxy.$refs.itemRef.validate().catch(() => false); if (!valid) return; submitting.value = true; try { await (form.value.itemId ? updateItem(form.value) : addItem(form.value)); proxy.$modal.msgSuccess(form.value.itemId ? '修改成功' : '新增成功'); open.value = false; getList() } finally { submitting.value = false } }
async function handleDelete(row) { const itemIds = row?.itemId ?? ids.value.join(','); await proxy.$modal.confirm('确认删除选中的物料吗？存在库存或业务单据的物料将无法删除。'); await delItem(itemIds); proxy.$modal.msgSuccess('删除成功'); getList() }

getList()
</script>

<style scoped lang="scss">
.wms-page { background: #f6f8fb; min-height: calc(100vh - 84px); }
.page-heading { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; h2 { margin: 0 0 6px; font-size: 22px; color: #1d2939; } p { margin: 0; color: #667085; } }
.search-card { margin-bottom: 14px; :deep(.el-card__body) { padding-bottom: 2px; } }
.table-card :deep(.el-card__body) { padding: 18px; }
@media (max-width: 768px) { .page-heading { align-items: flex-start; gap: 12px; } .page-heading p { display: none; } }
</style>
