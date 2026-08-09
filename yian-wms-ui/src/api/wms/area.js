import request from '@/utils/request'

export function listArea(query) {
  return request({ url: '/wms/area/list', method: 'get', params: query })
}

export function getArea(areaId) {
  return request({ url: `/wms/area/${areaId}`, method: 'get' })
}

export function addArea(data) {
  return request({ url: '/wms/area', method: 'post', data })
}

export function updateArea(data) {
  return request({ url: '/wms/area', method: 'put', data })
}

export function delArea(areaIds) {
  return request({ url: `/wms/area/${areaIds}`, method: 'delete' })
}
