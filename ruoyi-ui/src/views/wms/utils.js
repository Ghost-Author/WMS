export function rowsOf(response) {
  if (Array.isArray(response?.rows)) return response.rows
  if (Array.isArray(response?.data)) return response.data
  if (Array.isArray(response?.data?.rows)) return response.data.rows
  return []
}

export function totalOf(response, rows = []) {
  return Number(response?.total ?? response?.data?.total ?? rows.length)
}

export function dataOf(response) {
  return response?.data?.data ?? response?.data ?? {}
}

export function optionText(option, codeKey, nameKey) {
  const code = option?.[codeKey]
  const name = option?.[nameKey]
  return [code, name].filter(Boolean).join(' - ') || String(option?.label ?? '')
}

export const normalStatusOptions = [
  { value: '0', label: '启用', type: 'success' },
  { value: '1', label: '停用', type: 'info' }
]

export function normalStatus(status) {
  return normalStatusOptions.find(item => item.value === String(status)) || { label: status || '-', type: 'info' }
}

export function documentStatus(status) {
  return {
    DRAFT: { label: '草稿', type: 'warning' },
    COMPLETED: { label: '已完成', type: 'success' },
    CANCELLED: { label: '已取消', type: 'info' }
  }[status] || { label: status || '-', type: 'info' }
}

export function quantity(value) {
  const number = Number(value)
  return Number.isFinite(number) ? number.toLocaleString('zh-CN', { maximumFractionDigits: 4 }) : '-'
}
