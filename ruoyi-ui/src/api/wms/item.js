import request from '@/utils/request'

export function listItem(query) {
  return request({ url: '/wms/item/list', method: 'get', params: query })
}

export function getItem(itemId) {
  return request({ url: `/wms/item/${itemId}`, method: 'get' })
}

export function addItem(data) {
  return request({ url: '/wms/item', method: 'post', data })
}

export function updateItem(data) {
  return request({ url: '/wms/item', method: 'put', data })
}

export function delItem(itemIds) {
  return request({ url: `/wms/item/${itemIds}`, method: 'delete' })
}

export function getItemOptions(query) {
  return request({ url: '/wms/item/options', method: 'get', params: query })
}
