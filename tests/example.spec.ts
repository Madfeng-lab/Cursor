import { test, expect } from '@playwright/test';

// 这是一个通用的辅助函数，建议放在测试钩子里
async function enableFlutterSemantics(page) {
  // 等待 Flutter 渲染面板加载
  const glassPane = await page.waitForSelector('flt-glass-pane', { state: 'attached' });
  
  // 强制触发语义树开启
  await page.evaluate(() => {
    const semanticsHost = document.querySelector('flt-glass-pane')?.shadowRoot
                          ?.querySelector('flt-semantics-placeholder');
    if (semanticsHost) (semanticsHost as HTMLElement).click();
  });
}

test('验证首页训练状态和按钮点击', async ({ page }) => {
  // 1. 进入本地开发的地址
  await page.goto('http://localhost:56361');

  // 2. 开启语义支持（见上一步的函数）
  await enableFlutterSemantics(page);

  // 3. 定位元素：由于 Flutter 混淆严重，我们通过文本内容定位
  // Playwright 的 getByText 会自动处理 Flutter 的语义节点
  const startBtn = page.getByText('开始训练');
  await expect(startBtn).toBeVisible();

  // 4. 模拟点击
  await startBtn.click();

  // 5. 断言页面跳转或状态改变
  const workoutTitle = page.getByText('肌肉图谱');
  await expect(workoutTitle).toBeVisible();
});

test('视觉回归测试：对比 3D 动画状态', async ({ page }) => {
  await page.goto('http://localhost:8080/muscle-library');
  
  // 针对你的肌肉特定动作动画（.riv），最稳妥的是截图对比
  // Playwright 会自动对比当前的截图与“基准图”是否一致
  await expect(page).toHaveScreenshot('muscle-animation-state.png', {
    maxDiffPixelRatio: 0.05 // 允许 5% 的像素误差，因为 3D 渲染可能略有不同
  });
});