import request from '@/utils/request'

export function listReceipt(query) {
  return request({ url: '/wms/receipt/list', method: 'get', params: query })
}

export function getReceipt(receiptId) {
  return request({ url: `/wms/receipt/${receiptId}`, method: 'get' })
}

export function addReceipt(data) {
  return request({ url: '/wms/receipt', method: 'post', data })
}

export function updateReceipt(data) {
  return request({ url: '/wms/receipt', method: 'put', data })
}

export function delReceipt(receiptIds) {
  return request({ url: `/wms/receipt/${receiptIds}`, method: 'delete' })
}

export function completeReceipt(receiptId) {
  return request({ url: `/wms/receipt/${receiptId}/complete`, method: 'put' })
}

export function cancelReceipt(receiptId) {
  return request({ url: `/wms/receipt/${receiptId}/cancel`, method: 'put' })
}
