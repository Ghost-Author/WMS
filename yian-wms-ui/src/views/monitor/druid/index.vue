<template>
  <div class="app-container druid-page">
    <div class="welcome-panel">
      <div>
        <span class="eyebrow">DATABASE OBSERVABILITY</span>
        <h1>数据库运行监控</h1>
        <p>实时查看连接池、SQL 执行和数据库运行状态。</p>
      </div>
      <div class="welcome-actions">
        <span class="status-pill" :class="statusClass" role="status" aria-live="polite">
          <i />{{ statusText }}
        </span>
        <div class="welcome-mark"><el-icon><DataAnalysis /></el-icon></div>
      </div>
    </div>

    <el-card shadow="never" class="monitor-card">
      <template #header>
        <div class="card-header">
          <div>
            <span>数据库运行详情</span>
            <small>仅拥有数据监控权限的用户可以访问，会话闲置 15 分钟后自动失效</small>
          </div>
          <el-button type="primary" plain :loading="authorizing" @click="loadMonitor()">
            <el-icon><Refresh /></el-icon>刷新监控
          </el-button>
        </div>
      </template>

      <div class="monitor-stage">
        <div v-if="authorizing" class="loading-panel" role="status" aria-live="polite">
          <div class="loading-icon"><el-icon><Connection /></el-icon></div>
          <strong>正在建立安全监控会话</strong>
          <span>正在验证访问权限，请稍候…</span>
          <el-skeleton :rows="6" animated class="monitor-skeleton" />
        </div>

        <el-result
          v-else-if="loadError"
          icon="error"
          title="数据监控加载失败"
          :sub-title="loadError"
        >
          <template #extra>
            <el-button type="primary" @click="loadMonitor">重新加载</el-button>
          </template>
        </el-result>

        <div v-else class="frame-wrap">
          <div v-if="frameLoading" class="frame-loading">
            <el-icon class="is-loading"><Loading /></el-icon>
            <span>正在载入监控数据…</span>
          </div>
          <iframe
            :key="iframeKey"
            class="monitor-frame"
            :class="{ visible: !frameLoading }"
            :src="monitorUrl"
            title="数据库运行监控"
            frameborder="0"
            @load="handleFrameLoad"
          />
        </div>
      </div>
    </el-card>
  </div>
</template>

<script setup name="Druid">
import { createDruidSession } from '@/api/monitor/druid'

const monitorUrl = import.meta.env.VITE_APP_BASE_API + '/druid/index.html'
const authorizing = ref(true)
const frameLoading = ref(true)
const loadError = ref('')
const iframeKey = ref(0)
let frameTimer
let requestSequence = 0
let disposed = false
let sessionEstablishedAt = 0
let reauthorizeAttempts = 0
const SESSION_REFRESH_INTERVAL = 14 * 60 * 1000

const statusText = computed(() => {
  if (loadError.value) return '连接异常'
  if (authorizing.value || frameLoading.value) return '连接中'
  return '运行正常'
})
const statusClass = computed(() => {
  if (loadError.value) return 'is-error'
  if (authorizing.value || frameLoading.value) return 'is-loading'
  return 'is-online'
})

async function loadMonitor(resetAttempts = true) {
  const requestId = ++requestSequence
  if (resetAttempts) reauthorizeAttempts = 0
  clearTimeout(frameTimer)
  authorizing.value = true
  frameLoading.value = true
  loadError.value = ''
  try {
    await createDruidSession()
    if (disposed || requestId !== requestSequence) return
    sessionEstablishedAt = Date.now()
    iframeKey.value += 1
    authorizing.value = false
    frameTimer = setTimeout(() => {
      if (!disposed && requestId === requestSequence && frameLoading.value) {
        frameLoading.value = false
        loadError.value = '监控服务响应超时，请稍后重试'
      }
    }, 15000)
  } catch (error) {
    if (disposed || requestId !== requestSequence) return
    authorizing.value = false
    frameLoading.value = false
    loadError.value = error?.message || '无法建立监控会话，请确认账号拥有数据监控权限'
  }
}

function applyFrameTheme(frame) {
  const document = frame.contentDocument
  if (!document?.head || document.getElementById('yian-wms-druid-theme')) return
  const style = document.createElement('style')
  style.id = 'yian-wms-druid-theme'
  style.textContent = `
    html, body { background: #f5f7fb !important; color: #101828; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", sans-serif; }
    .navbar .navbar-inner { border: 0 !important; background: linear-gradient(120deg, #155eef 0%, #2970ff 55%, #53b1fd 100%) !important; box-shadow: 0 4px 14px rgba(21, 94, 239, .18) !important; }
    .navbar .brand, .navbar .nav > li > a { color: rgba(255,255,255,.92) !important; text-shadow: none !important; }
    .navbar .nav > .active > a, .navbar .nav > li > a:hover { color: #fff !important; background: rgba(255,255,255,.13) !important; box-shadow: none !important; }
    .well, .panel, .table { border-color: #eaecf0 !important; border-radius: 10px; box-shadow: none !important; }
    .table > thead > tr > th { color: #475467; background: #f9fafb; border-bottom-color: #eaecf0; }
    .btn-primary { border-color: #1570ef !important; background: #1570ef !important; }
    a { color: #175cd3; }
  `
  document.head.appendChild(style)
  if (!document.querySelector('meta[name="viewport"]')) {
    const viewport = document.createElement('meta')
    viewport.name = 'viewport'
    viewport.content = 'width=device-width, initial-scale=1'
    document.head.appendChild(viewport)
  }
}

function handleFrameLoad(event) {
  clearTimeout(frameTimer)
  try {
    const currentPath = event.target.contentWindow?.location?.pathname || ''
    const frameDocument = event.target.contentDocument
    if (currentPath.endsWith('/druid/login.html') || currentPath.endsWith('/druid/nopermit.html')) {
      if (reauthorizeAttempts >= 1) {
        frameLoading.value = false
        loadError.value = '监控会话未能建立，请确认账号拥有数据监控权限'
        return
      }
      reauthorizeAttempts += 1
      loadMonitor(false)
      return
    }
    const isDruidPage = currentPath.includes('/druid/')
      && (frameDocument?.title?.startsWith('Druid ') || frameDocument?.querySelector('#dataTable'))
    if (!isDruidPage) {
      frameLoading.value = false
      loadError.value = '监控服务返回了异常页面，请稍后重试'
      return
    }
    applyFrameTheme(event.target)
  } catch (error) {
    console.warn('无法应用监控页面主题', error)
  }
  reauthorizeAttempts = 0
  frameLoading.value = false
}

function restoreSessionIfNeeded() {
  if (!document.hidden && !authorizing.value && Date.now() - sessionEstablishedAt >= SESSION_REFRESH_INTERVAL) {
    loadMonitor()
  }
}

onMounted(() => {
  window.addEventListener('focus', restoreSessionIfNeeded)
  document.addEventListener('visibilitychange', restoreSessionIfNeeded)
})
onActivated(restoreSessionIfNeeded)
onDeactivated(() => clearTimeout(frameTimer))
onBeforeUnmount(() => {
  disposed = true
  requestSequence += 1
  clearTimeout(frameTimer)
  window.removeEventListener('focus', restoreSessionIfNeeded)
  document.removeEventListener('visibilitychange', restoreSessionIfNeeded)
})
loadMonitor()
</script>

<style scoped lang="scss">
.druid-page { min-height: calc(100vh - 84px); color: #101828; background: #f5f7fb; }
.welcome-panel { position: relative; overflow: hidden; display: flex; align-items: center; justify-content: space-between; min-height: 138px; padding: 25px 34px; margin-bottom: 18px; color: #fff; border-radius: 14px; background: linear-gradient(120deg, #155eef 0%, #2970ff 50%, #53b1fd 100%); box-shadow: 0 10px 28px rgba(21, 94, 239, .18); &::after { position: absolute; top: -110px; right: -80px; width: 260px; height: 260px; border: 45px solid rgba(255,255,255,.08); border-radius: 50%; content: ''; } h1 { margin: 8px 0; font-size: 27px; letter-spacing: 1px; } p { margin: 0; color: rgba(255,255,255,.82); } }
.eyebrow { color: #d1e9ff; font-size: 11px; font-weight: 700; letter-spacing: 2px; }
.welcome-actions { z-index: 1; display: flex; align-items: center; gap: 16px; }
.welcome-mark { display: grid; place-items: center; width: 70px; height: 70px; border: 1px solid rgba(255,255,255,.2); border-radius: 20px; background: rgba(255,255,255,.14); font-size: 36px; }
.status-pill { display: inline-flex; align-items: center; gap: 8px; padding: 8px 13px; border: 1px solid rgba(255,255,255,.22); border-radius: 999px; background: rgba(255,255,255,.13); color: #fff; font-size: 13px; font-weight: 600; backdrop-filter: blur(8px); i { width: 8px; height: 8px; border-radius: 50%; background: #d0d5dd; } &.is-online i { background: #6ce9a6; box-shadow: 0 0 0 4px rgba(108,233,166,.18); } &.is-loading i { background: #fec84b; box-shadow: 0 0 0 4px rgba(254,200,75,.18); } &.is-error i { background: #fda29b; box-shadow: 0 0 0 4px rgba(253,162,155,.18); } }
.monitor-card { overflow: hidden; border: 1px solid #eaecf0; border-radius: 12px; :deep(.el-card__header) { padding: 17px 20px; } :deep(.el-card__body) { padding: 0; } }
.card-header { display: flex; align-items: center; justify-content: space-between; gap: 16px; > div { display: flex; flex-direction: column; gap: 4px; } span { font-size: 16px; font-weight: 650; } small { color: #98a2b3; font-weight: 400; } }
.monitor-stage { position: relative; min-height: 560px; height: calc(100vh - 306px); background: #f8fafc; }
.loading-panel { display: flex; flex-direction: column; align-items: center; padding: 48px 8%; color: #667085; > strong { margin: 14px 0 5px; color: #101828; font-size: 17px; } > span { font-size: 13px; } }
.loading-icon { display: grid; place-items: center; width: 54px; height: 54px; border-radius: 16px; color: #1570ef; background: #eff8ff; font-size: 27px; }
.monitor-skeleton { width: min(920px, 100%); margin-top: 34px; }
.frame-wrap { position: relative; width: 100%; height: 100%; }
.frame-loading { position: absolute; inset: 0; z-index: 2; display: flex; align-items: center; justify-content: center; gap: 10px; color: #667085; background: #f8fafc; .el-icon { color: #1570ef; font-size: 22px; } }
.monitor-frame { display: block; width: 100%; height: 100%; border: 0; opacity: 0; background: #f5f7fb; transition: opacity .2s ease; &.visible { opacity: 1; } }
:deep(.el-result) { height: 100%; justify-content: center; }
@media (max-width: 768px) { .druid-page { padding: 12px; } .welcome-panel { min-height: 126px; padding: 21px; h1 { font-size: 22px; } } .welcome-mark { display: none; } .status-pill { padding: 7px 10px; } .card-header { align-items: flex-start; flex-direction: column; .el-button { width: 100%; } } .monitor-stage { min-height: 520px; height: calc(100vh - 350px); } }
</style>
