import { createRouter, createWebHistory } from 'vue-router';

const routes = [
  {
    path: '/',
    name: 'home',
    component: () => import('../views/Home.vue'),
    meta: { title: '首页' }
  },
  {
    path: '/server',
    name: 'server',
    component: () => import('../views/ServerConfig.vue'),
    meta: { title: '服务器配置' }
  },
  {
    path: '/tunnel',
    name: 'tunnel',
    component: () => import('../views/TunnelConfig.vue'),
    meta: { title: '穿透配置' }
  },
  {
    path: '/logs',
    name: 'logs',
    component: () => import('../views/Logs.vue'),
    meta: { title: '运行日志' }
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

router.beforeEach((to, from, next) => {
  document.title = `${to.meta.title || 'WSL内网穿透工具'}`;
  next();
});

export default router;