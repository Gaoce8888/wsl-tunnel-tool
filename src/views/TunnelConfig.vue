<template>
  <div class="tunnel-config-container">
    <el-row :gutter="20">
      <el-col :span="24" class="mb-20">
        <div class="app-card">
          <div class="card-header flex-between">
            <h2>穿透配置</h2>
            <el-button type="primary" @click="showAddTunnelDialog">新增转发规则</el-button>
          </div>
          
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
            <el-table-column label="操作" width="240" fixed="right">
              <template #default="{row}">
                <el-button-group>
                  <el-button 
                    :type="row.status === 'running' ? 'danger' : 'success'" 
                    size="small" 
                    :icon="row.status === 'running' ? 'CircleClose' : 'VideoPlay'"
                    @click="toggleTunnel(row)">
                    {{ row.status === 'running' ? '停止' : '启动' }}
                  </el-button>
                  <el-button type="primary" size="small" icon="Edit" @click="editTunnel(row)">编辑</el-button>
                  <el-button type="danger" size="small" icon="Delete" @click="deleteTunnel(row)">删除</el-button>
                </el-button-group>
              </template>
            </el-table-column>
          </el-table>
          
          <div class="text-center mt-20" v-if="tunnelList.length === 0 && !loading">
            <el-empty description="暂无穿透隧道配置">
              <el-button type="primary" @click="showAddTunnelDialog">添加转发规则</el-button>
            </el-empty>
          </div>
        </div>
      </el-col>
    </el-row>
    
    <el-dialog 
      v-model="tunnelDialog.visible" 
      :title="tunnelDialog.isEdit ? '编辑转发规则' : '新增转发规则'" 
      width="600px"
      @closed="resetTunnelForm">
      <el-form :model="tunnelForm" :rules="tunnelRules" ref="tunnelFormRef" label-width="120px">
        <el-form-item label="规则名称" prop="name">
          <el-input v-model="tunnelForm.name" placeholder="例如：SSH隧道或Web服务"></el-input>
        </el-form-item>
        
        <el-form-item label="协议类型" prop="type">
          <el-select v-model="tunnelForm.type" placeholder="选择协议类型" style="width: 100%">
            <el-option label="TCP" value="tcp"></el-option>
            <el-option label="UDP" value="udp"></el-option>
            <el-option label="HTTP" value="http"></el-option>
            <el-option label="HTTPS" value="https"></el-option>
          </el-select>
        </el-form-item>
        
        <el-form-item label="本地端口" prop="localPort">
          <el-input-number v-model="tunnelForm.localPort" :min="1" :max="65535" controls-position="right"></el-input-number>
        </el-form-item>
        
        <el-form-item label="远程端口" prop="remotePort">
          <el-input-number v-model="tunnelForm.remotePort" :min="1" :max="65535" controls-position="right"></el-input-number>
        </el-form-item>
        
        <template v-if="tunnelForm.type === 'http' || tunnelForm.type === 'https'">
          <el-form-item label="域名" prop="domain">
            <el-input v-model="tunnelForm.domain" placeholder="例如：example.com"></el-input>
          </el-form-item>
        </template>
        
        <el-divider>高级选项</el-divider>
        
        <el-form-item label="带宽限制">
          <el-input-number v-model="tunnelForm.bandwidthLimit" :min="0" :step="1" controls-position="right">
            <template #suffix>KB/s</template>
          </el-input-number>
          <div class="form-help">0表示不限制</div>
        </el-form-item>
        
        <el-form-item label="额外选项">
          <el-checkbox v-model="tunnelForm.useCompression">压缩传输</el-checkbox>
          <el-checkbox v-model="tunnelForm.useEncryption">加密传输</el-checkbox>
        </el-form-item>
        
        <el-form-item label="自定义参数">
          <el-input v-model="tunnelForm.customParams" type="textarea" rows="3"></el-input>
          <div class="form-help">每行一个参数，格式为key=value</div>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="tunnelDialog.visible = false">取消</el-button>
          <el-button type="primary" @click="saveTunnel" :loading="tunnelDialog.saving">
            {{ tunnelDialog.isEdit ? '保存更改' : '创建规则' }}
          </el-button>
        </span>
      </template>
    </el-dialog>
    
    <el-dialog v-model="configDialog.visible" title="隧道配置代码" width="800px">
      <div class="config-code">
        <pre><code>{{ generatedConfig }}</code></pre>
      </div>
      <div class="mt-20 flex-between">
        <div>此配置可以直接用于FRP客户端</div>
        <el-button type="primary" @click="copyConfig" :icon="documentCopy">复制配置</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { ref, reactive, computed, onMounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { documentCopy } from '@element-plus/icons-vue';

export default {
  name: 'TunnelConfigView',
  setup() {
    const loading = ref(false);
    const tunnelFormRef = ref(null);
    
    // 隧道列表
    const tunnelList = ref([
      { id: 1, name: 'SSH隧道', type: 'tcp', localPort: 22, remotePort: 2222, domain: '', bandwidthLimit: 0, useCompression: true, useEncryption: true, customParams: '', status: 'running' },
      { id: 2, name: 'Web服务', type: 'http', localPort: 8080, remotePort: 80, domain: 'example.com', bandwidthLimit: 1024, useCompression: true, useEncryption: false, customParams: 'proxy_protocol_version=v2', status: 'running' },
      { id: 3, name: '测试UDP', type: 'udp', localPort: 8000, remotePort: 8000, domain: '', bandwidthLimit: 0, useCompression: false, useEncryption: false, customParams: '', status: 'stopped' }
    ]);
    
    // 表单数据
    const tunnelForm = reactive({
      id: null,
      name: '',
      type: 'tcp',
      localPort: 80,
      remotePort: 80,
      domain: '',
      bandwidthLimit: 0,
      useCompression: true,
      useEncryption: false,
      customParams: '',
      status: 'stopped'
    });
    
    // 表单验证规则
    const tunnelRules = {
      name: [
        { required: true, message: '请输入规则名称', trigger: 'blur' }
      ],
      type: [
        { required: true, message: '请选择协议类型', trigger: 'change' }
      ],
      localPort: [
        { required: true, message: '请输入本地端口', trigger: 'blur' },
        { type: 'number', min: 1, max: 65535, message: '端口范围为1-65535', trigger: 'blur' }
      ],
      remotePort: [
        { required: true, message: '请输入远程端口', trigger: 'blur' },
        { type: 'number', min: 1, max: 65535, message: '端口范围为1-65535', trigger: 'blur' }
      ],
      domain: [
        { required: true, message: '使用HTTP/HTTPS协议需要填写域名', trigger: 'blur', validator: (rule, value, callback) => {
          if ((tunnelForm.type === 'http' || tunnelForm.type === 'https') && !value) {
            callback(new Error('使用HTTP/HTTPS协议需要填写域名'));
          } else {
            callback();
          }
        }}
      ]
    };
    
    // 对话框状态
    const tunnelDialog = reactive({
      visible: false,
      isEdit: false,
      saving: false
    });
    
    const configDialog = reactive({
      visible: false,
      tunnel: null
    });
    
    const generatedConfig = computed(() => {
      if (!configDialog.tunnel) return '';
      
      const tunnel = configDialog.tunnel;
      let config = `# FRP客户端配置 - ${tunnel.name}\n`;
      config += `[common]\n`;
      config += `server_addr = 服务器地址\n`;
      config += `server_port = 7000\n\n`;
      
      config += `[${tunnel.name.replace(/\s+/g, '-').toLowerCase()}]\n`;
      config += `type = ${tunnel.type}\n`;
      config += `local_ip = 127.0.0.1\n`;
      config += `local_port = ${tunnel.localPort}\n`;
      config += `remote_port = ${tunnel.remotePort}\n`;
      
      if ((tunnel.type === 'http' || tunnel.type === 'https') && tunnel.domain) {
        config += `custom_domains = ${tunnel.domain}\n`;
      }
      
      if (tunnel.useCompression) {
        config += `use_compression = true\n`;
      }
      
      if (tunnel.useEncryption) {
        config += `use_encryption = true\n`;
      }
      
      if (tunnel.bandwidthLimit > 0) {
        config += `bandwidth_limit = ${tunnel.bandwidthLimit}KB\n`;
      }
      
      if (tunnel.customParams) {
        const params = tunnel.customParams.split('\n').filter(line => line.trim());
        for (const param of params) {
          config += `${param}\n`;
        }
      }
      
      return config;
    });
    
    // 重置表单
    const resetTunnelForm = () => {
      tunnelFormRef.value?.resetFields();
      Object.assign(tunnelForm, {
        id: null,
        name: '',
        type: 'tcp',
        localPort: 80,
        remotePort: 80,
        domain: '',
        bandwidthLimit: 0,
        useCompression: true,
        useEncryption: false,
        customParams: '',
        status: 'stopped'
      });
    };
    
    // 显示添加隧道对话框
    const showAddTunnelDialog = () => {
      resetTunnelForm();
      tunnelDialog.isEdit = false;
      tunnelDialog.visible = true;
    };
    
    // 获取协议标签样式
    const getProtocolTag = (protocol) => {
      const tags = {
        'tcp': 'primary',
        'udp': 'warning',
        'http': 'success',
        'https': 'info'
      };
      return tags[protocol] || 'default';
    };
    
    // 切换隧道状态
    const toggleTunnel = (tunnel) => {
      loading.value = true;
      
      // 模拟API请求
      setTimeout(() => {
        tunnel.status = tunnel.status === 'running' ? 'stopped' : 'running';
        
        ElMessage({
          type: 'success',
          message: `隧道 ${tunnel.name} 已${tunnel.status === 'running' ? '启动' : '停止'}`
        });
        
        loading.value = false;
      }, 500);
    };
    
    // 编辑隧道
    const editTunnel = (tunnel) => {
      // 填充表单数据
      Object.keys(tunnelForm).forEach(key => {
        if (key in tunnel) {
          tunnelForm[key] = tunnel[key];
        }
      });
      
      tunnelDialog.isEdit = true;
      tunnelDialog.visible = true;
    };
    
    // 删除隧道
    const deleteTunnel = async (tunnel) => {
      try {
        await ElMessageBox.confirm(
          `确定要删除隧道 "${tunnel.name}" 吗？`,
          '删除确认',
          {
            confirmButtonText: '确定',
            cancelButtonText: '取消',
            type: 'warning',
          }
        );
        
        loading.value = true;
        
        // 模拟API请求
        setTimeout(() => {
          tunnelList.value = tunnelList.value.filter(t => t.id !== tunnel.id);
          
          ElMessage({
            type: 'success',
            message: `隧道 ${tunnel.name} 已删除`
          });
          
          loading.value = false;
        }, 500);
      } catch (error) {
        // 用户取消删除
      }
    };
    
    // 保存隧道配置
    const saveTunnel = async () => {
      if (!tunnelFormRef.value) return;
      
      await tunnelFormRef.value.validate(async (valid) => {
        if (!valid) {
          ElMessage.error('请填写所有必填字段');
          return;
        }
        
        tunnelDialog.saving = true;
        
        try {
          // 模拟API请求
          await new Promise(resolve => setTimeout(resolve, 800));
          
          if (tunnelDialog.isEdit) {
            // 更新现有隧道
            const index = tunnelList.value.findIndex(t => t.id === tunnelForm.id);
            if (index !== -1) {
              tunnelList.value[index] = { ...tunnelForm };
              ElMessage.success('隧道配置已更新!');
            }
          } else {
            // 添加新隧道
            const newId = Math.max(0, ...tunnelList.value.map(t => t.id)) + 1;
            tunnelList.value.push({
              ...tunnelForm,
              id: newId
            });
            ElMessage.success('新隧道已添加!');
          }
          
          tunnelDialog.visible = false;
        } catch (error) {
          ElMessage.error('保存失败: ' + error.message);
        } finally {
          tunnelDialog.saving = false;
        }
      });
    };
    
    // 复制配置
    const copyConfig = () => {
      navigator.clipboard.writeText(generatedConfig.value)
        .then(() => {
          ElMessage.success('配置已复制到剪贴板');
        })
        .catch(() => {
          ElMessage.error('复制失败，请手动复制');
        });
    };
    
    onMounted(() => {
      // 加载隧道列表
      loading.value = true;
      setTimeout(() => {
        loading.value = false;
      }, 500);
    });
    
    return {
      loading,
      tunnelList,
      tunnelForm,
      tunnelRules,
      tunnelDialog,
      tunnelFormRef,
      configDialog,
      generatedConfig,
      documentCopy,
      showAddTunnelDialog,
      getProtocolTag,
      toggleTunnel,
      editTunnel,
      deleteTunnel,
      saveTunnel,
      resetTunnelForm,
      copyConfig
    };
  }
};
</script>

<style lang="scss" scoped>
.tunnel-config-container {
  .el-input-number {
    width: 180px;
  }
  
  .form-help {
    font-size: 12px;
    color: #909399;
    line-height: 1.2;
    margin-top: 5px;
  }
  
  .config-code {
    background-color: #1e1e1e;
    color: #d4d4d4;
    border-radius: 4px;
    padding: 16px;
    overflow-x: auto;
    
    pre {
      margin: 0;
      font-family: monospace;
      font-size: 14px;
      line-height: 1.5;
      white-space: pre-wrap;
    }
  }
}
</style>