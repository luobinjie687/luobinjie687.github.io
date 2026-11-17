# 罗彬杰 · 个人主页

**线上地址：<https://luobinjie687.github.io/>**（已上线，HTTPS，手机可访问）

纯静态站点：没有构建步骤、没有依赖、不需要 Node。改完文件刷新浏览器就能看到效果。

## 文件结构

```
my-homepage/
├─ index.html          页面骨架（一般不用改）
├─ publish.cmd         ★ 双击这个发布上线
├─ data/
│  └─ site.js          ★ 所有文字内容都在这里，改这个文件就行
├─ assets/
│  ├─ style.css        样式与配色（改 :root 里的变量可换主色）
│  ├─ main.js          渲染逻辑（一般不用改）
│  └─ avatar.jpg       （可选）头像，放进来后在 site.js 里写 "assets/avatar.jpg"
├─ tools/
│  ├─ check-site.ps1   语法自检（改完 site.js 可以先跑它）
│  ├─ publish.ps1      publish.cmd 实际调用的脚本
│  └─ publish-api.ps1  github.com 不通时改走 API 的备用通道
└─ .nojekyll           给 GitHub Pages 用的空文件，别删
```

## 本地预览

直接双击 `index.html` 即可。或在本目录运行：

```powershell
python -m http.server 8080
```

然后打开 http://localhost:8080

## 页面板块

学习方向 / 教育背景 / 课程与技能 / 学习路线 / 论文 / 科研项目 / 近况 / 联系方式

**论文**和**科研项目**现在的内容是空数组，所以这两个板块（以及导航里的入口）会自动隐藏。
以后有了论文或参与课题，往 `site.js` 里填一条，板块就会自动出现 —— 不用改 HTML。

## 日常更新（三种都很快）

1. **改文字 / 加近况** → 只编辑 `data/site.js`，保存，刷新。
2. **加一门课 / 一个技能** → 在 `skills` 里对应分组的 `items` 数组里加一项。
3. **加一条近况** → 在 `news` 数组最前面加：
   ```js
   { date: "2026-11", text: "内容" }
   ```

以后真的加了论文，按这个格式填：

```js
{
  year: 2027,
  title: "论文标题",
  authors: "Luo B, Zhang X, et al.",
  venue: "期刊名",
  note: "共同作者",        // 可留空
  selected: false,         // true 会打上 ★ 代表作
  links: [{ label: "DOI", href: "https://..." }]
}
```

也可以直接跟 AI 说"帮我把这篇论文加到主页上"，把引文粘过去就行。

## 更新线上版本（两种方式，选一种）

### 方式一：双击发布（改了本地文件之后）

1. 编辑 `data\site.js`，保存
2. 双击项目根目录的 **`publish.cmd`**
3. 等 1 分钟，刷新 <https://luobinjie687.github.io/>（强制刷新 `Ctrl+F5`）

`publish.cmd` 会自动做四件事：先检查 JS 语法（有错就停下，不会把坏页面推上去）、提交、推送、确认结果。

**关于这台机器的网络**：`github.com:443` 会间歇性连不上（表现为推送超时），而 `api.github.com` 一直稳定。所以脚本里准备了两条通道：先测 `github.com` 通不通，通则正常 `git push`，不通就自动改走 GitHub REST API 发布（内容一样，只是不经过 github.com）。你不需要管，脚本会自己选。

推送失败时它还会自动重试；两条路都失败才报错，而且此时你的修改已经安全提交在本地，网络好了再双击一次就行。

只想检查语法、不想发布：双击 `tools\check-site.ps1` 或运行 `powershell -ExecutionPolicy Bypass -File tools\check-site.ps1`。

### 方式二：在 GitHub 网页上直接改（不用电脑也行）

手机或任何浏览器打开 <https://github.com/luobinjie687/luobinjie687.github.io>，进入 `data/site.js`，点右上角铅笔图标编辑，改完点 **Commit changes**，约 1 分钟后网站自动更新。

## 站点信息

| 项目 | 值 |
| --- | --- |
| 仓库 | <https://github.com/luobinjie687/luobinjie687.github.io>（公开） |
| 托管 | GitHub Pages，`main` 分支根目录，自动构建 |
| 费用 | 0 元（公开仓库的 Pages 免费，无限期） |
| 部署方式 | 推送到 `main` → Pages 自动重建（约 20 秒～1 分钟） |

仓库名必须保持 `luobinjie687.github.io`，改成别的名字网址会变成 `/<仓库名>/`，主页里的相对链接仍能用，但地址变长。

## 想自定义域名

仓库 Settings → Pages → Custom domain，填域名并在域名商处加 CNAME 记录，勾选 Enforce HTTPS。域名约 ¥60–100/年，证书免费。不是必须做的。

## 常见替换点

| 想改什么 | 改哪里 |
| --- | --- |
| 姓名 / 学校 / 简介 | `data/site.js` 顶部 |
| 教育背景、入学年份 | `data/site.js` 的 `education` |
| 课程与技能标签 | `data/site.js` 的 `skills` |
| 学习路线 | `data/site.js` 的 `plan` |
| 主色调 | `assets/style.css` 的 `--accent` |
| 页面标题 / SEO 描述 | `index.html` 的 `<title>` 和 `<meta name="description">` |
| 头像 | 放图片到 `assets/`，在 `site.js` 里写路径 |
