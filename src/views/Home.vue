<template>
  <div class="home-container">
    <el-row :gutter="20">
      <el-col :span="24">
        <div class="app-card">
          <div class="card-header">
            <h2>系统状态</h2>
          </div>
          <div class="system-status">
            <el-row :gutter="20">
              <el-col :xs="24" :sm="12" :md="8">
                <div class="status-card">
                  <div class="status-icon">
                    <el-icon><Connection /></el-icon>
                  </div>
                  <div class="status-info">
                    <div class="status-title">服务器连接</div>
                    <div class="status-value">
                      <span class="status-tag" :class="serverStatus.status">
                        {{ serverStatus.text }}
                      </span>
                    </div>
                  </div>
                </div>
              </el-col>
              <el-col :xs="24" :sm="12" :md="8">
                <div class="status-card">
                  <div class="status-icon">
                    <el-icon><Monitor /></el-icon>
                  </div>
                  <div class="status-info">
                    <div class="status-title">活跃隧道</div>
                    <div class="status-value">
                      <el-tag type="success" v-if="tunnelStatus.active > 0">{{ tunnelStatus.active }} 个隧道运行中</el-tag>
                      <el-tag type="info" v-else>无活跃隧道</el-tag>
                    </div>
                  </div>
                </div>
              </el-col>
              <el-col :xs="24" :sm="12" :md="8">
                <div class="status-card">
                  <div class="status-icon">
                    <el-icon><Odometer /></el-icon>
                  </div>
                  <div class="status-info">
                    <div class="status-title">流量统计</div>
                    <div class="status-value">
                      <div>传入: {{ trafficStats.inbound }}</div>
                      <div>传出: {{ trafficStats.outbound }}</div>
                    </div>
                  </div>
                </div>
              </el-col>
            </el-row>
          </div>
        </div>
      </el-col>
    </el-row>

    <el-row :gutter="20" class="mt-20">
      <el-col :span="24">
        <div class="app-card">
          <div class="card-header">
            <h2>隧道概览</h2>
          </div>
          <div class="tunnel-overview">
            <el-table :data="tunnelList" style="width: 100%" v-loading="loading">
              <el-table-column prop="name" label="隧道名称" min-width="120" />
              <el-table-column prop="type" label="协议类型" width="100">
                <template #default="{row}">
                  <el-tag :type="getProtocolTag(row.type)">{{ row.type }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="localPort" label="本地端口" width="100" />
              <el-table-column prop="remotePort" label="远程端口" width="100" />
              <el-table-column prop="status" label="状态" width="100">
                <template #default="{row}">
                  <span class="status-tag" :class="row.status">
                    {{ row.status === 'running' ? '运行中' : row.status === 'stopped' ? '已停止' : '错误' }}
                  </span>
                </template>
              </el-table-column>
              <el-table-column label="操作" width="150" fixed="right">
                <template #default="{row}">
                  <el-button 
                    :type="row.status === 'running' ? 'danger' : 'success'" 
                    size="small" 
                    :icon="row.status === 'running' ? 'CircleClose' : 'VideoPlay'"
                    @click="toggleTunnel(row)">
                    {{ row.status === 'running' ? '停止' : '启动' }}
                  </el-button>
                </template>
              </el-table-column>
            </el-table>
            
            <div class="text-center mt-20" v-if="tunnelList.length === 0 && !loading">
              <el-empty description="暂无隧道配置">
                <el-button type="primary" @click="goToConfig">添加隧道</el-button>
              </el-empty>
            </div>
          </div>
        </div>
      </el-col>
    </el-row>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { Connection, Monitor, Odometer } from '@element-plus/icons-vue';

export default {
  name: 'HomeView',
  components: { Connection, Monitor, Odometer },
  setup() {
    const router = useRouter();
    const loading = ref(false);
    
    // 模拟数据 - 实际应从API获取
    const serverStatus = ref({ status: 'running', text: '已连接' });
    const tunnelStatus = ref({ active: 2, total: 3 });
    const trafficStats = ref({ inbound: '1.2 GB', outbound: '368 MB' });
    
    const tunnelList = ref([
      { id: 1, name: 'SSH隧道', type: 'tcp', localPort: 22, remotePort: 2222, status: 'running' },
      { id: 2, name: 'Web服务器', type: 'http', localPort: 8080, remotePort: 80, status: 'running' },
      { id: 3, name: '测试服务', type: 'udp', localPort: 8000, remotePort: 8000, status: 'stopped' }
    ]);
    
    const getProtocolTag = (protocol) => {
      const tags = {
        'tcp': 'primary',
        'udp': 'warning',
        'http': 'success',
        'https': 'info'
      };
      return tags[protocol] || 'default';
    };
    
    const toggleTunnel = (tunnel) => {
      loading.value = true;
      
      // 模拟API请求
      setTimeout(() => {
        tunnel.status = tunnel.status === 'running' ? 'stopped' : 'running';
        tunnelStatus.value.active = tunnelList.value.filter(t => t.status === 'running').length;
        
        ElMessage({
          type: 'success',
          message: `隧道 ${tunnel.name} 已${tunnel.status === 'running' ? '启动' : '停止'}`
        });
        
        loading.value = false;
      }, 500);
    };
    
    const goToConfig = () => {
      router.push('/tunnel');
    };
    
    onMounted(() => {
      // 这里应当调用API获取实际数据
      loading.value = true;
      setTimeout(() => {
        loading.value = false;
      }, 500);
    });
    
    return {
      loading,
      serverStatus,
      tunnelStatus,
      trafficStats,
      tunnelList,
      getProtocolTag,
      toggleTunnel,
      goToConfig
    };
  }
};
</script>

<style lang="scss" scoped>
.home-container {
  .system-status {
    margin-top: 20px;
    
    .status-card {
      display: flex;
      align-items: center;
      padding: 15px;
      background-color: #f5f7fa;
      border-radius: 4px;
      margin-bottom: 20px;
      height: 80px;
      
      .status-icon {
        font-size: 24px;
        margin-right: 15px;
        color: var(--primary-color);
      }
      
      .status-info {
        flex: 1;
        
        .status-title {
          font-size: 14px;
          color: var(--regular-text);
          margin-bottom: 5px;
        }
        
        .status-value {
          font-size: 16px;
          font-weight: bold;
          color: var(--primary-text);
        }
      }
    }
  }
  
  .tunnel-overview {
    margin-top: 10px;
  }
}
</style>