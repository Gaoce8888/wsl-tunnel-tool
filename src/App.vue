<template>
  <div class="app-container">
    <el-config-provider :locale="zhCn">
      <el-container>
        <el-header height="60px">
          <div class="header-container">
            <div class="logo">
              <h2>WSL内网穿透配置工具</h2>
            </div>
            <el-menu 
              :default-active="activeIndex" 
              mode="horizontal" 
              router 
              background-color="#2d3a4b" 
              text-color="#fff" 
              active-text-color="#ffd04b">
              <el-menu-item index="/">首页</el-menu-item>
              <el-menu-item index="/server">服务器配置</el-menu-item>
              <el-menu-item index="/tunnel">穿透配置</el-menu-item>
              <el-menu-item index="/logs">运行日志</el-menu-item>
            </el-menu>
          </div>
        </el-header>
        <el-main>
          <router-view />
        </el-main>
        <el-footer height="40px">
          <div class="footer-container">
            <span>© 2025 WSL内网穿透配置工具</span>
          </div>
        </el-footer>
      </el-container>
    </el-config-provider>
  </div>
</template>

<script>
import { ref, computed } from 'vue';
import { useRoute } from 'vue-router';
import zhCn from 'element-plus/lib/locale/lang/zh-cn';

export default {
  name: 'App',
  setup() {
    const route = useRoute();
    const activeIndex = computed(() => route.path);
    return { activeIndex, zhCn };
  }
};
</script>

<style>
html, body {
  margin: 0;
  padding: 0;
  height: 100%;
  font-family: 'Helvetica Neue', Helvetica, 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', Arial, sans-serif;
}

#app {
  height: 100%;
}

.app-container {
  height: 100vh;
}

.el-container {
  height: 100%;
}

.el-header {
  background-color: #2d3a4b;
  color: #fff;
  padding: 0;
}

.header-container {
  display: flex;
  align-items: center;
  height: 100%;
}

.logo {
  margin-right: 20px;
  padding-left: 16px;
}

.logo h2 {
  margin: 0;
  color: #fff;
}

.el-main {
  background-color: #f0f2f5;
  padding: 20px;
}

.el-footer {
  background-color: #f5f7fa;
  color: #909399;
  line-height: 40px;
  text-align: center;
}

.footer-container {
  text-align: center;
}
</style>