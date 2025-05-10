<template>
  <div class="logs-container">
    <el-row :gutter="20">
      <el-col :span="24">
        <div class="app-card">
          <div class="card-header flex-between">
            <h2>运行日志</h2>
            <div class="log-controls">
              <el-button-group>
                <el-button :type="logFilter === 'all' ? 'primary' : 'default'" @click="logFilter = 'all'">全部</el-button>
                <el-button :type="logFilter === 'system' ? 'primary' : 'default'" @click="logFilter = 'system'">系统</el-button>
                <el-button :type="logFilter === 'connection' ? 'primary' : 'default'" @click="logFilter = 'connection'">连接</el-button>
                <el-button :type="logFilter === 'error' ? 'primary' : 'default'" @click="logFilter = 'error'">错误</el-button>
              </el-button-group>
              <el-button type="danger" icon="Delete" @click="clearLogs" class="ml-10">清空日志</el-button>
            </div>
          </div>
          
          <div class="logs-header flex-between">
            <div class="search-box">
              <el-input 
                v-model="searchKeyword" 
                placeholder="搜索日志内容" 
                prefix-icon="Search" 
                clearable
                @clear="resetSearch"
              ></el-input>
            </div>
            <div class="log-pagination">
              <el-pagination 
                v-model:current-page="currentPage"
                layout="prev, pager, next"
                :page-size="pageSize"
                :total="totalLogs"
                @current-change="handlePageChange"
              ></el-pagination>
            </div>
          </div>
          
          <div class="logs-table">
            <el-table 
              :data="filteredLogs" 
              style="width: 100%" 
              v-loading="loading"
              height="calc(100vh - 320px)"
              :empty-text="emptyText">
              <el-table-column prop="timestamp" label="时间" width="180" sortable>
                <template #default="{row}">
                  {{ formatDate(row.timestamp) }}
                </template>
              </el-table-column>
              <el-table-column prop="type" label="类型" width="120">
                <template #default="{row}">
                  <el-tag :type="getLogTypeTag(row.type)" size="small">
                    {{ getLogTypeLabel(row.type) }}
                  </el-tag>
                </template>
              </el-table-column>
              <el-table-column prop="source" label="来源" width="150" />
              <el-table-column prop="message" label="日志内容" min-width="250" show-overflow-tooltip />
              <el-table-column label="操作" width="120" fixed="right">
                <template #default="{row}">
                  <el-button 
                    text 
                    type="primary" 
                    @click="viewLogDetail(row)"
                  >详情</el-button>
                </template>
              </el-table-column>
            </el-table>
          </div>
        </div>
      </el-col>
    </el-row>
    
    <el-dialog v-model="logDetailDialog.visible" title="日志详情" width="800px">
      <div class="log-detail" v-if="logDetailDialog.log">
        <div class="detail-item">
          <div class="detail-label">时间</div>
          <div class="detail-value">{{ formatDate(logDetailDialog.log.timestamp) }}</div>
        </div>
        <div class="detail-item">
          <div class="detail-label">类型</div>
          <div class="detail-value">
            <el-tag :type="getLogTypeTag(logDetailDialog.log.type)">
              {{ getLogTypeLabel(logDetailDialog.log.type) }}
            </el-tag>
          </div>
        </div>
        <div class="detail-item">
          <div class="detail-label">来源</div>
          <div class="detail-value">{{ logDetailDialog.log.source }}</div>
        </div>
        <div class="detail-item">
          <div class="detail-label">日志内容</div>
          <div class="detail-value log-message">{{ logDetailDialog.log.message }}</div>
        </div>
        <div class="detail-item" v-if="logDetailDialog.log.details">
          <div class="detail-label">详细信息</div>
          <div class="detail-value">
            <pre class="log-details">{{ logDetailDialog.log.details }}</pre>
          </div>
        </div>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { ref, computed, onMounted, watch } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';

export default {
  name: 'LogsView',
  setup() {
    const loading = ref(false);
    const logs = ref([]);
    const searchKeyword = ref('');
    const logFilter = ref('all');
    const currentPage = ref(1);
    const pageSize = ref(20);
    
    const logDetailDialog = ref({
      visible: false,
      log: null
    });
    
    // 模拟生成日志数据
    const generateLogs = () => {
      const types = ['info', 'warning', 'error', 'connection'];
      const sources = ['System', 'SSH隧道', 'Web服务', 'UDP隧道', 'FRP客户端', 'FRP服务端'];
      const messages = [
        '服务启动成功',
        '隧道连接已建立',
        '隧道连接已断开',
        '端口转发规则添加成功',
        '连接被拒绝，端口可能被占用',
        '认证失败，请检查凭据',
        '连接超时，请检查网络',
        '收到新的连接请求',
        '已恢复与服务器的连接',
        '无法解析主机名',
        '远程服务器返回错误码: 404',
        '配置文件加载成功',
        '流量限制已达到，连接被限制',
        '证书验证失败'        
      ];
      
      const generatedLogs = [];
      const now = new Date();
      
      for (let i = 0; i < 100; i++) {
        const type = types[Math.floor(Math.random() * types.length)];
        const source = sources[Math.floor(Math.random() * sources.length)];
        const message = messages[Math.floor(Math.random() * messages.length)];
        const timestamp = new Date(now - Math.floor(Math.random() * 7 * 24 * 60 * 60 * 1000));
        
        let details = null;
        if (type === 'error') {
          details = `错误堆栈信息:\n  at Connection.onConnect (frp/client.js:142:23)\n  at WebSocket.onOpen (net/websocket.js:87:12)\n  at WebSocket._handleOpen (ws/lib/websocket.js:205:10)\n  at Connection.handleEvent (net/connection.js:368:14)`;  
        } else if (type === 'connection') {
          details = `连接信息:\n  本地地址: 127.0.0.1:${8000 + Math.floor(Math.random() * 1000)}\n  远程地址: 203.0.113.${Math.floor(Math.random() * 255)}:${Math.floor(Math.random() * 10000) + 1024}\n  协议: TCP\n  传输字节: ${Math.floor(Math.random() * 100000)} bytes`;  
        }
        
        generatedLogs.push({
          id: i + 1,
          timestamp,
          type,
          source,
          message,
          details
        });
      }
      
      // 按时间排序，最新的在前面
      generatedLogs.sort((a, b) => b.timestamp - a.timestamp);
      
      return generatedLogs;
    };
    
    // 过滤日志
    const filteredLogs = computed(() => {
      let result = logs.value;
      
      if (logFilter.value !== 'all') {
        if (logFilter.value === 'system') {
          result = result.filter(log => log.type === 'info' || log.type === 'warning');
        } else {
          result = result.filter(log => log.type === logFilter.value);
        }
      }
      
      if (searchKeyword.value) {
        const keyword = searchKeyword.value.toLowerCase();
        result = result.filter(log => 
          log.message.toLowerCase().includes(keyword) || 
          log.source.toLowerCase().includes(keyword) ||
          (log.details && log.details.toLowerCase().includes(keyword))
        );
      }
      
      // 分页处理
      const startIndex = (currentPage.value - 1) * pageSize.value;
      const endIndex = startIndex + pageSize.value;
      return result.slice(startIndex, endIndex);
    });
    
    // 计算总日志数
    const totalLogs = computed(() => {
      let result = logs.value;
      
      if (logFilter.value !== 'all') {
        if (logFilter.value === 'system') {
          result = result.filter(log => log.type === 'info' || log.type === 'warning');
        } else {
          result = result.filter(log => log.type === logFilter.value);
        }
      }
      
      if (searchKeyword.value) {
        const keyword = searchKeyword.value.toLowerCase();
        result = result.filter(log => 
          log.message.toLowerCase().includes(keyword) || 
          log.source.toLowerCase().includes(keyword) ||
          (log.details && log.details.toLowerCase().includes(keyword))
        );
      }
      
      return result.length;
    });
    
    // 空状态文本
    const emptyText = computed(() => {
      if (searchKeyword.value) {
        return '没有找到匹配的日志记录';
      }
      return '暂无日志记录';
    });
    
    // 格式化日期
    const formatDate = (date) => {
      if (!(date instanceof Date)) {
        date = new Date(date);
      }
      return date.toLocaleString('zh-CN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      });
    };
    
    // 获取日志类型标签
    const getLogTypeLabel = (type) => {
      const labels = {
        'info': '信息',
        'warning': '警告',
        'error': '错误',
        'connection': '连接'
      };
      return labels[type] || type;
    };
    
    // 获取日志类型标签样式
    const getLogTypeTag = (type) => {
      const tags = {
        'info': 'info',
        'warning': 'warning',
        'error': 'danger',
        'connection': 'success'
      };
      return tags[type] || 'default';
    };
    
    // 处理分页
    const handlePageChange = (page) => {
      currentPage.value = page;
    };
    
    // 查看日志详情
    const viewLogDetail = (log) => {
      logDetailDialog.value.log = log;
      logDetailDialog.value.visible = true;
    };
    
    // 重置搜索
    const resetSearch = () => {
      searchKeyword.value = '';
    };
    
    // 清空日志
    const clearLogs = async () => {
      try {
        await ElMessageBox.confirm(
          '确定要清空所有日志记录吗？此操作不可恢复。',
          '清空确认',
          {
            confirmButtonText: '确定',
            cancelButtonText: '取消',
            type: 'warning',
          }
        );
        
        logs.value = [];
        ElMessage.success('所有日志已清空');
      } catch (error) {
        // 用户取消操作
      }
    };
    
    // 监听过滤器变化，重置到第一页
    watch([searchKeyword, logFilter], () => {
      currentPage.value = 1;
    });
    
    onMounted(() => {
      // 加载日志数据
      loading.value = true;
      setTimeout(() => {
        logs.value = generateLogs();
        loading.value = false;
      }, 500);
    });
    
    return {
      loading,
      logs,
      filteredLogs,
      totalLogs,
      searchKeyword,
      logFilter,
      currentPage,
      pageSize,
      logDetailDialog,
      emptyText,
      formatDate,
      getLogTypeLabel,
      getLogTypeTag,
      handlePageChange,
      viewLogDetail,
      resetSearch,
      clearLogs
    };
  }
};
</script>

<style lang="scss" scoped>
.logs-container {
  .logs-header {
    margin: 15px 0;
    
    .search-box {
      width: 300px;
    }
  }
  
  .ml-10 {
    margin-left: 10px;
  }
  
  .log-detail {
    .detail-item {
      margin-bottom: 15px;
      
      .detail-label {
        font-weight: bold;
        margin-bottom: 5px;
        color: var(--primary-text);
      }
      
      .detail-value {
        color: var(--regular-text);
        
        &.log-message {
          white-space: pre-wrap;
          word-break: break-all;
        }
      }
      
      .log-details {
        background-color: #f5f7fa;
        border-radius: 4px;
        padding: 10px;
        margin: 0;
        font-family: monospace;
        white-space: pre-wrap;
        word-break: break-all;
        max-height: 300px;
        overflow-y: auto;
      }
    }
  }
}
</style>