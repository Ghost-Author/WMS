import request from '@/utils/request'

// 为当前 WMS 用户建立短期数据库监控会话
export function createDruidSession() {
  return request({
    url: '/monitor/druid/session',
    method: 'post',
    headers: { repeatSubmit: false }
  })
}
