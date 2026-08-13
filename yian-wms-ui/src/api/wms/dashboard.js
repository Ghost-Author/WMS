import request from '@/utils/request'

// 查询 WMS 首页业务摘要
export function getDashboardSummary() {
  return request({
    url: '/wms/dashboard/summary',
    method: 'get'
  })
}

// 查询近期库存流水
export function listRecentMovements(query) {
  return request({
    url: '/wms/dashboard/recentMovements',
    method: 'get',
    params: query
  })
}

// 查询近 7 日完成入出库趋势
export function getOperationTrend() {
  return request({
    url: '/wms/dashboard/operationTrend',
    method: 'get'
  })
}

// 查询启用仓库的当前库存分布
export function getWarehouseStockDistribution() {
  return request({
    url: '/wms/dashboard/warehouseStockDistribution',
    method: 'get'
  })
}
