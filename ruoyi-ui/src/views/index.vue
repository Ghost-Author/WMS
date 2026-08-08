<template>
  <wms-dashboard v-if="canViewDashboard" />
  <div v-else class="app-container home-page">
    <div class="welcome-card">
      <div class="welcome-icon"><el-icon><House /></el-icon></div>
      <div>
        <span class="eyebrow">WELCOME</span>
        <h1>欢迎使用智仓管理平台</h1>
        <p>请从左侧菜单进入您有权限访问的功能模块。</p>
      </div>
    </div>
  </div>
</template>

<script setup name="Index">
import WmsDashboard from '@/views/wms/dashboard/index.vue'
import auth from '@/plugins/auth'

const canViewDashboard = computed(() => auth.hasPermi('wms:dashboard:list'))
</script>

<style scoped lang="scss">
.home-page { min-height: calc(100vh - 84px); background: #f5f7fb; }
.welcome-card { display: flex; align-items: center; gap: 22px; max-width: 760px; padding: 34px; margin: 48px auto; border: 1px solid #e4e7ec; border-radius: 16px; background: #fff; box-shadow: 0 12px 32px rgba(16, 24, 40, .06); }
.welcome-icon { display: grid; flex: none; place-items: center; width: 68px; height: 68px; border-radius: 18px; color: #175cd3; background: #eff8ff; font-size: 32px; }
.eyebrow { color: #1570ef; font-size: 11px; font-weight: 700; letter-spacing: 2px; }
h1 { margin: 7px 0 8px; color: #101828; font-size: 26px; }
p { margin: 0; color: #667085; }
@media (max-width: 768px) { .welcome-card { align-items: flex-start; padding: 24px; margin: 24px 0; } h1 { font-size: 22px; } }
</style>
