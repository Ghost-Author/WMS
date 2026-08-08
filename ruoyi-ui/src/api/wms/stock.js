import request from '@/utils/request'

export function listStock(query) {
  return request({ url: '/wms/stock/list', method: 'get', params: query })
}

export function listLowStock(query) {
  return request({ url: '/wms/stock/lowStock', method: 'get', params: query })
}

export function listStockMovements(query) {
  return request({ url: '/wms/stock/movement/list', method: 'get', params: query })
}
