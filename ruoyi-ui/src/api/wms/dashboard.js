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
