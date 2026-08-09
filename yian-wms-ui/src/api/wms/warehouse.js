import request from '@/utils/request'

export function listWarehouse(query) {
  return request({ url: '/wms/warehouse/list', method: 'get', params: query })
}

export function getWarehouse(warehouseId) {
  return request({ url: `/wms/warehouse/${warehouseId}`, method: 'get' })
}

export function addWarehouse(data) {
  return request({ url: '/wms/warehouse', method: 'post', data })
}

export function updateWarehouse(data) {
  return request({ url: '/wms/warehouse', method: 'put', data })
}

export function delWarehouse(warehouseIds) {
  return request({ url: `/wms/warehouse/${warehouseIds}`, method: 'delete' })
}

export function getWarehouseOptions(query) {
  return request({ url: '/wms/warehouse/options', method: 'get', params: query })
}
