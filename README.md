# 罗彬杰 · 个人主页

纯静态站点：没有构建步骤、没有依赖、不需要 Node。改完文件刷新浏览器就能看到效果。

## 文件结构

```
my-homepage/
├─ index.html          页面骨架（一般不用改）
├─ data/
│  └─ site.js          ★ 所有文字内容都在这里，改这个文件就行
├─ assets/
│  ├─ style.css        样式与配色（改 :root 里的变量可换主色）
│  └─ main.js          渲染逻辑（一般不用改）
├─ assets/avatar.jpg   （可选）头像，放进来后在 site.js 里写 "assets/avatar.jpg"
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

## 发布到公网（GitHub Pages）

1. 在 GitHub 新建仓库，例如 `my-homepage`
2. 本目录执行（仓库已初始化时）：
   ```powershell
   git add .
   git commit -m "update homepage"
   git push
   ```
3. 仓库 Settings → Pages → Source 选 `main` / root → 保存
4. 等 1 分钟，访问 `https://<用户名>.github.io/my-homepage/`

若仓库名就叫 `<用户名>.github.io`，则直接访问 `https://<用户名>.github.io/`。

## 想自定义域名

仓库 Settings → Pages → Custom domain，填域名并在域名商处加 CNAME 记录，勾选 Enforce HTTPS。

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
