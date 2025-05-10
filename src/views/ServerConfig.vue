<template>
  <div class="server-config-container">
    <el-row :gutter="20">
      <el-col :span="24">
        <div class="app-card">
          <div class="card-header">
            <h2>服务器配置</h2>
          </div>
          <el-form :model="serverForm" :rules="rules" ref="serverFormRef" label-width="120px" label-position="left">
            <el-form-item label="服务器地址" prop="host">
              <el-input v-model="serverForm.host" placeholder="例如：example.com 或 10.0.0.1"></el-input>
            </el-form-item>
            
            <el-form-item label="SSH端口" prop="port">
              <el-input-number v-model="serverForm.port" :min="1" :max="65535" controls-position="right"></el-input-number>
            </el-form-item>
            
            <el-form-item label="用户名" prop="username">
              <el-input v-model="serverForm.username" placeholder="SSH登录用户名"></el-input>
            </el-form-item>
            
            <el-form-item label="认证方式" prop="authType">
              <el-radio-group v-model="serverForm.authType">
                <el-radio label="password">密码认证</el-radio>
                <el-radio label="key">密钥认证</el-radio>
              </el-radio-group>
            </el-form-item>
            
            <el-form-item label="密码" prop="password" v-if="serverForm.authType === 'password'">
              <el-input v-model="serverForm.password" type="password" placeholder="SSH登录密码" show-password></el-input>
            </el-form-item>
            
            <el-form-item label="私钥文件" prop="privateKey" v-if="serverForm.authType === 'key'">
              <el-input v-model="serverForm.privateKey" placeholder="私钥文件路径" clearable>
                <template #append>
                  <el-button @click="selectKeyFile">选择</el-button>
                </template>
              </el-input>
            </el-form-item>
            
            <el-form-item label="私钥密码" prop="passphrase" v-if="serverForm.authType === 'key'">
              <el-input v-model="serverForm.passphrase" type="password" placeholder="私钥密码（如果有）" show-password clearable></el-input>
            </el-form-item>
            
            <el-divider>组件安装</el-divider>
            
            <el-form-item label="安装组件">
              <el-checkbox-group v-model="serverForm.components">
                <el-checkbox label="frp">FRP（快速反向代理）</el-checkbox>
                <el-checkbox label="nginx">Nginx（Web服务器）</el-checkbox>
                <el-checkbox label="certbot">Certbot（SSL证书）</el-checkbox>
              </el-checkbox-group>
            </el-form-item>
            
            <div class="form-actions">
              <el-button @click="resetForm">重置</el-button>
              <el-button type="primary" @click="testConnection" :loading="testing">测试连接</el-button>
              <el-button type="success" @click="installComponents" :loading="installing" :disabled="!connectionTested">安装组件</el-button>
              <el-button type="primary" @click="saveConfig" :loading="saving">保存配置</el-button>
            </div>
          </el-form>
        </div>
      </el-col>
    </el-row>
    
    <el-dialog v-model="installDialog" title="安装进度" width="600px">
      <div class="install-progress">
        <div v-for="(component, index) in installProgress" :key="index" class="component-progress">
          <div class="component-name">{{ getComponentName(component.name) }}</div>
          <el-progress :percentage="component.progress" :status="component.status"></el-progress>
          <div class="component-message" v-if="component.message">{{ component.message }}</div>
        </div>
      </div>
      <div class="install-logs" v-if="installLogs.length > 0">
        <div class="logs-header">安装日志</div>
        <div class="logs-content">
          <p v-for="(log, index) in installLogs" :key="index" :class="log.type">{{ log.message }}</p>
        </div>
      </div>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="installDialog = false" :disabled="isInstalling">取消</el-button>
          <el-button type="primary" @click="completeInstallation" :disabled="isInstalling || !allInstalled">完成</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script>
import { ref, reactive, computed, onMounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';

export default {
  name: 'ServerConfigView',
  setup() {
    const serverFormRef = ref(null);
    const connectionTested = ref(false);
    const testing = ref(false);
    const installing = ref(false);
    const saving = ref(false);
    const installDialog = ref(false);
    
    const serverForm = reactive({
      host: '',
      port: 22,
      username: '',
      authType: 'password',
      password: '',
      privateKey: '',
      passphrase: '',
      components: ['frp']
    });
    
    const rules = {
      host: [
        { required: true, message: '请输入服务器地址', trigger: 'blur' },
      ],
      port: [
        { required: true, message: '请输入SSH端口', trigger: 'blur' },
        { type: 'number', min: 1, max: 65535, message: '端口范围为1-65535', trigger: 'blur' }
      ],
      username: [
        { required: true, message: '请输入用户名', trigger: 'blur' }
      ],
      password: [
        { required: true, message: '请输入密码', trigger: 'blur', validator: (rule, value, callback) => {
          if (serverForm.authType === 'password' && !value) {
            callback(new Error('请输入密码'));
          } else {
            callback();
          }
        }}
      ],
      privateKey: [
        { required: true, message: '请提供私钥文件路径', trigger: 'blur', validator: (rule, value, callback) => {
          if (serverForm.authType === 'key' && !value) {
            callback(new Error('请提供私钥文件路径'));
          } else {
            callback();
          }
        }}
      ]
    };
    
    // 模拟安装进度
    const installProgress = reactive([
      { name: 'frp', progress: 0, status: 'warning', message: '' },
      { name: 'nginx', progress: 0, status: 'warning', message: '' },
      { name: 'certbot', progress: 0, status: 'warning', message: '' }
    ]);
    
    const installLogs = ref([]);
    
    const isInstalling = computed(() => {
      return installProgress.some(comp => comp.progress > 0 && comp.progress < 100);
    });
    
    const allInstalled = computed(() => {
      return serverForm.components.every(comp => {
        const progress = installProgress.find(p => p.name === comp);
        return progress && progress.progress === 100 && progress.status === 'success';
      });
    });
    
    // 从本地存储加载配置
    const loadConfig = () => {
      const savedConfig = localStorage.getItem('wsl-tunnel-server-config');
      if (savedConfig) {
        try {
          const config = JSON.parse(savedConfig);
          Object.assign(serverForm, config);
          // 不加载密码和私钥密码
          serverForm.password = '';
          serverForm.passphrase = '';
          ElMessage.success('已加载保存的配置');
        } catch (error) {
          console.error('加载配置失败:', error);
        }
      }
    };
    
    const resetForm = () => {
      serverFormRef.value?.resetFields();
      connectionTested.value = false;
    };
    
    const getComponentName = (name) => {
      const names = {
        'frp': 'FRP（快速反向代理）',
        'nginx': 'Nginx（Web服务器）',
        'certbot': 'Certbot（SSL证书）'
      };
      return names[name] || name;
    };
    
    const selectKeyFile = () => {
      // 在实际应用中，这里应该打开一个文件选择对话框
      ElMessage.info('请输入私钥文件的绝对路径，例如：/home/user/.ssh/id_rsa');
    };
    
    const testConnection = async () => {
      if (!serverFormRef.value) return;
      
      await serverFormRef.value.validate(async (valid) => {
        if (!valid) {
          ElMessage.error('请填写所有必填字段');
          return;
        }
        
        testing.value = true;
        
        try {
          // 这里应该调用API测试SSH连接
          // 模拟API调用
          await new Promise(resolve => setTimeout(resolve, 1500));
          
          ElMessage.success('连接成功!');
          connectionTested.value = true;
        } catch (error) {
          ElMessage.error('连接失败: ' + error.message);
        } finally {
          testing.value = false;
        }
      });
    };
    
    const installComponents = async () => {
      if (!connectionTested.value) {
        ElMessage.warning('请先测试连接');
        return;
      }
      
      if (serverForm.components.length === 0) {
        ElMessage.warning('请至少选择一个组件进行安装');
        return;
      }
      
      try {
        await ElMessageBox.confirm(
          '确定要在服务器上安装所选组件吗？这可能需要一些时间。',
          '安装确认',
          {
            confirmButtonText: '确定',
            cancelButtonText: '取消',
            type: 'warning',
          }
        );
        
        // 重置安装进度
        installProgress.forEach(comp => {
          comp.progress = 0;
          comp.status = 'warning';
          comp.message = '';
        });
        
        installLogs.value = [];
        installDialog.value = true;
        installing.value = true;
        
        // 模拟安装过程
        for (const component of serverForm.components) {
          const progressItem = installProgress.find(item => item.name === component);
          if (!progressItem) continue;
          
          // 模拟进度更新
          progressItem.status = 'warning';
          for (let i = 0; i <= 100; i += 10) {
            progressItem.progress = i;
            
            // 添加一些模拟日志
            if (i === 0) {
              installLogs.value.push({ type: 'info', message: `开始安装 ${getComponentName(component)}...` });
            } else if (i === 50) {
              installLogs.value.push({ type: 'info', message: `${getComponentName(component)} 安装中...` });
            } else if (i === 100) {
              installLogs.value.push({ type: 'success', message: `${getComponentName(component)} 安装完成!` });
              progressItem.status = 'success';
              progressItem.message = '安装完成';
            }
            
            await new Promise(resolve => setTimeout(resolve, 200));
          }
        }
        
        ElMessage.success('所有组件已成功安装!');
      } catch (error) {
        if (error !== 'cancel') {
          ElMessage.error('安装过程出错: ' + error);
        }
      } finally {
        installing.value = false;
      }
    };
    
    const saveConfig = async () => {
      if (!serverFormRef.value) return;
      
      await serverFormRef.value.validate(async (valid) => {
        if (!valid) {
          ElMessage.error('请填写所有必填字段');
          return;
        }
        
        saving.value = true;
        
        try {
          // 创建一个不包含敏感信息的配置对象用于保存
          const configToSave = { ...serverForm };
          delete configToSave.password;
          delete configToSave.passphrase;
          
          localStorage.setItem('wsl-tunnel-server-config', JSON.stringify(configToSave));
          ElMessage.success('配置已保存!');
        } catch (error) {
          ElMessage.error('保存配置失败: ' + error.message);
        } finally {
          saving.value = false;
        }
      });
    };
    
    const completeInstallation = () => {
      installDialog.value = false;
      ElMessage({
        type: 'success',
        message: '组件安装完成，现在您可以配置隧道了!',
        duration: 3000
      });
    };
    
    onMounted(() => {
      // 加载已保存的配置
      loadConfig();
    });
    
    return {
      serverFormRef,
      serverForm,
      rules,
      connectionTested,
      testing,
      installing,
      saving,
      installDialog,
      installProgress,
      installLogs,
      isInstalling,
      allInstalled,
      resetForm,
      testConnection,
      installComponents,
      saveConfig,
      selectKeyFile,
      getComponentName,
      completeInstallation
    };
  }
};
</script>

<style lang="scss" scoped>
.server-config-container {
  .el-input-number {
    width: 180px;
  }
  
  .install-progress {
    margin-bottom: 20px;
    
    .component-progress {
      margin-bottom: 15px;
      
      .component-name {
        margin-bottom: 5px;
        font-weight: bold;
      }
      
      .component-message {
        margin-top: 5px;
        color: #67c23a;
        font-size: 12px;
      }
    }
  }
  
  .install-logs {
    margin-top: 20px;
    border: 1px solid #e4e7ed;
    border-radius: 4px;
    overflow: hidden;
    
    .logs-header {
      background-color: #f5f7fa;
      padding: 8px 12px;
      font-weight: bold;
      border-bottom: 1px solid #e4e7ed;
    }
    
    .logs-content {
      padding: 12px;
      max-height: 200px;
      overflow-y: auto;
      background-color: #1e1e1e;
      color: #ffffff;
      font-family: monospace;
      
      p {
        margin: 3px 0;
        font-size: 12px;
        line-height: 1.5;
        white-space: pre-wrap;
        word-break: break-all;
        
        &.info {
          color: #ffffff;
        }
        
        &.success {
          color: #67c23a;
        }
        
        &.error {
          color: #f56c6c;
        }
        
        &.warning {
          color: #e6a23c;
        }
      }
    }
  }
}
</style>