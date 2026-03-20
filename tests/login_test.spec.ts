import { test, expect } from '@playwright/test';

test('Flutter 健身应用登录流测试', async ({ page }) => {
  // 1. 跳转到你本地开发的地址
  await page.goto('http://localhost:56361');

  // 2. 等待 Flutter 加载（通常寻找特定的渲染容器）
await page.waitForSelector('flt-glass-pane', { state: 'attached' });
  // 3. 关键：激活 Flutter 的语义树 (开启辅助功能，让 Playwright 能“看见”文字)
  // 这是处理 Flutter Web 无法直接定位按钮的最稳妥办法
  await page.evaluate(() => {
    const semanticsHost = document.querySelector('flt-glass-pane')?.shadowRoot
                          ?.querySelector('flt-semantics-placeholder');
    if (semanticsHost) (semanticsHost as HTMLElement).click();
  });

  // 4. 输入账号和密码
  // 假设你的输入框有 Label 文字叫 "手机号" 和 "密码"
  const phoneInput = page.getByLabel('邮箱'); 
  const passwordInput = page.getByLabel('密码');

  await phoneInput.fill('13800000000');
  await passwordInput.fill('123456');

  // 5. 点击登录按钮
  // 使用 getByRole 或 getByText，Playwright 会自动匹配 Flutter 暴露出来的语义节点
  const loginBtn = page.getByRole('button', { name: '登录' });
  await loginBtn.click();

  // 6. 验证是否进入了主页（比如主页有“肌肉库”或“今日计划”字样）
  await expect(page.getByText('今日计划')).toBeVisible({ timeout: 10000 });
  
  console.log('登录回归测试通过！');
});