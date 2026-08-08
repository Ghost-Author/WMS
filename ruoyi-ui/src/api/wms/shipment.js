import request from '@/utils/request'

export function listShipment(query) {
  return request({ url: '/wms/shipment/list', method: 'get', params: query })
}

export function getShipment(shipmentId) {
  return request({ url: `/wms/shipment/${shipmentId}`, method: 'get' })
}

export function addShipment(data) {
  return request({ url: '/wms/shipment', method: 'post', data })
}

export function updateShipment(data) {
  return request({ url: '/wms/shipment', method: 'put', data })
}

export function delShipment(shipmentIds) {
  return request({ url: `/wms/shipment/${shipmentIds}`, method: 'delete' })
}

export function completeShipment(shipmentId) {
  return request({ url: `/wms/shipment/${shipmentId}/complete`, method: 'put' })
}
