import request from '@/utils/request'

export function listLocation(query) {
  return request({ url: '/wms/location/list', method: 'get', params: query })
}

export function getLocation(locationId) {
  return request({ url: `/wms/location/${locationId}`, method: 'get' })
}

export function addLocation(data) {
  return request({ url: '/wms/location', method: 'post', data })
}

export function updateLocation(data) {
  return request({ url: '/wms/location', method: 'put', data })
}

export function delLocation(locationIds) {
  return request({ url: `/wms/location/${locationIds}`, method: 'delete' })
}

export function getLocationOptions(query) {
  return request({ url: '/wms/location/options', method: 'get', params: query })
}
