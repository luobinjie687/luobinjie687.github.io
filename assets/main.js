/* ============================================================
 *  渲染逻辑：把 data/site.js 里的内容画到页面上
 *  一般不需要改这个文件；想改内容请改 data/site.js
 * ============================================================ */
(function () {
  "use strict";

  var S = window.SITE || {};

  /* ---------- 小工具 ---------- */
  function $(id) { return document.getElementById(id); }

  function el(tag, cls, html) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (html != null) n.innerHTML = html;
    return n;
  }

  // 转义，避免内容里的特殊字符破坏结构
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function list(key) {
    var v = S[key];
    return Array.isArray(v) ? v : [];
  }

  /* ---------- 图标 ---------- */
  var ICONS = {
    mail: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"><rect x="2.5" y="4.5" width="19" height="15" rx="2.5"/><path d="m3 7 9 6 9-6"/></svg>',
    scholar: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"><path d="M12 3 2 8l10 5 10-5-10-5Z"/><path d="M4 12v5c0 1.5 3.5 3 8 3s8-1.5 8-3v-5"/></svg>',
    orcid: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"><circle cx="12" cy="12" r="9"/><path d="M9 9v7"/><path d="M9 9.2h.01"/><path d="M13 16v-4.5c0-1.4 1-2.5 2.4-2.5S18 10.1 18 11.5V16"/></svg>',
    github: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"><path d="M9 19c-4 1.5-4-2.5-6-3m12 5v-3.5c0-1 .1-1.4-.5-2 2.8-.3 5.5-1.4 5.5-6a4.6 4.6 0 0 0-1.3-3.2 4.2 4.2 0 0 0-.1-3.2s-1.1-.3-3.5 1.3a12 12 0 0 0-6.2 0C6.5 2.8 5.4 3.1 5.4 3.1a4.2 4.2 0 0 0-.1 3.2A4.6 4.6 0 0 0 4 9.5c0 4.6 2.7 5.7 5.5 6-.6.6-.6 1.2-.5 2V20"/></svg>',
    cv: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"><path d="M14 2.5H6.5a2 2 0 0 0-2 2v15a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V8z"/><path d="M14 2.5V8h5.5"/><path d="M8 13h8M8 17h5"/></svg>',
    link: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"><path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1"/></svg>'
  };

  /* ---------- 基本信息 ---------- */
  function renderHead() {
    var name = S.name || "你的名字";
    document.title = name + " · 个人主页";
    document.querySelector('meta[name="author"]').setAttribute("content", name);
    $("name").textContent = name;
    $("name-en").textContent = S.nameEn || "";
    $("title").textContent = S.title || "";
    $("affil").textContent = S.affiliation || "";
    $("bio").textContent = S.bio || "";
    $("brand").textContent = name;
    $("foot-name").textContent = name;
    $("year").textContent = new Date().getFullYear();

    // 头像：配了图片就用图片，否则显示姓氏首字
    var box = $("avatar");
    if (S.avatar) {
      var img = el("img", "avatar");
      img.src = S.avatar;
      img.alt = name;
      img.loading = "lazy";
      box.replaceWith(img);
    } else {
      box.textContent = name.trim().charAt(0);
    }

    // 首屏关键词
    var facts = $("facts");
    list("facts").forEach(function (t) {
      facts.appendChild(el("span", "fact", esc(t)));
    });

    // 对外链接
    var row = $("links");
    row.innerHTML = "";
    list("links").forEach(function (l) {
      var a = el("a", "link-btn");
      a.href = l.href || "#";
      a.innerHTML = (ICONS[l.icon] || ICONS.link) + "<span>" + esc(l.label) + "</span>";
      if (/^https?:/i.test(a.href)) { a.target = "_blank"; a.rel = "noopener"; }
      row.appendChild(a);
    });
  }

  /* ---------- 学习方向 ---------- */
  function renderResearch() {
    var box = $("research-grid");
    box.innerHTML = "";
    list("research").forEach(function (r) {
      var c = el("div", "research-card");
      c.appendChild(el("h3", null, esc(r.title)));
      c.appendChild(el("p", null, esc(r.text)));
      box.appendChild(c);
    });
  }

  /* ---------- 教育背景 ---------- */
  function renderEducation() {
    var box = $("edu-list");
    box.innerHTML = "";
    list("education").forEach(function (e) {
      var d = el("div", "edu");
      var head = el("div", "edu-head");
      var left = el("div", "edu-school", esc(e.school || ""));
      if (e.period) left.innerHTML += ' <span class="tag">' + esc(e.period) + "</span>";
      head.appendChild(left);
      if (e.degree) head.appendChild(el("div", "edu-degree", esc(e.degree)));
      d.appendChild(head);
      if (e.desc) d.appendChild(el("div", "edu-desc", esc(e.desc)));
      box.appendChild(d);
    });
  }

  /* ---------- 课程与技能 ---------- */
  function renderSkills() {
    var box = $("skill-list");
    box.innerHTML = "";
    list("skills").forEach(function (g) {
      var wrap = el("div", "skill-group");
      wrap.appendChild(el("div", "skill-label", esc(g.group || "")));
      var chips = el("div", "chips");
      (Array.isArray(g.items) ? g.items : []).forEach(function (t) {
        chips.appendChild(el("span", "chip", esc(t)));
      });
      wrap.appendChild(chips);
      box.appendChild(wrap);
    });
  }

  /* ---------- 学习路线 / 项目（共用一套渲染） ---------- */
  // 带圆点的竖向步骤条；role 里含「进行中」视为当前阶段
  function renderEntries(key, boxId) {
    var box = $(boxId);
    if (!box) return;
    box.innerHTML = "";
    list(key).forEach(function (p) {
      var current = p.role && /进行中|当前|current/i.test(p.role);
      var d = el("div", current ? "plan-item is-current" : "plan-item");
      d.appendChild(el("span", "plan-dot"));

      var head = el("div", "plan-head");
      var left = el("div", "plan-name", esc(p.name || ""));
      if (p.role) {
        left.innerHTML += ' <span class="' + (current ? "tag tag-warm" : "tag") + '">' + esc(p.role) + "</span>";
      }
      head.appendChild(left);
      if (p.period) head.appendChild(el("div", "plan-period", esc(p.period)));
      d.appendChild(head);
      if (p.desc) d.appendChild(el("div", "plan-desc", esc(p.desc)));
      box.appendChild(d);
    });
  }

  /* ---------- 论文 ---------- */
  function renderPubs() {
    var box = $("pub-list");
    box.innerHTML = "";

    var arr = list("publications").slice().sort(function (a, b) {
      return (b.year || 0) - (a.year || 0);
    });
    if (!arr.length) return;

    // 取英文名里的姓氏（最后一个词），用于在作者列表中加粗自己
    var parts = (S.nameEn || "").trim().split(/\s+/).filter(Boolean);
    var myLastName = parts.length ? parts[parts.length - 1] : "";

    arr.forEach(function (p) {
      var item = el("div", "pub");
      item.appendChild(el("div", "pub-year", esc(p.year || "")));

      var body = el("div");
      var title = el("h3", "pub-title");
      title.innerHTML = (p.selected ? '<span class="star" title="代表作">★</span>' : "") + esc(p.title);
      body.appendChild(title);

      var authorsHtml = esc(p.authors || "");
      if (myLastName) {
        authorsHtml = authorsHtml.replace(
          new RegExp("\\b(" + myLastName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")\\b", "g"),
          '<span class="me">$1</span>'
        );
      }
      body.appendChild(el("div", "pub-authors", authorsHtml));
      if (p.venue) body.appendChild(el("div", "pub-venue", esc(p.venue)));

      var meta = el("div", "pub-meta");
      if (p.note) meta.appendChild(el("span", "tag", esc(p.note)));
      (Array.isArray(p.links) ? p.links : []).forEach(function (l) {
        var a = el("a", null, esc(l.label));
        a.href = l.href || "#";
        if (/^https?:/i.test(a.href)) { a.target = "_blank"; a.rel = "noopener"; }
        meta.appendChild(a);
      });
      body.appendChild(meta);

      item.appendChild(body);
      box.appendChild(item);
    });
  }

  /* ---------- 近况 ---------- */
  function renderNews() {
    var box = $("news-list");
    box.innerHTML = "";
    list("news").forEach(function (n) {
      var li = el("li");
      li.appendChild(el("div", "tl-date", esc(n.date)));
      li.appendChild(el("div", "tl-text", esc(n.text)));
      box.appendChild(li);
    });
  }

  /* ---------- 联系方式 ---------- */
  function renderContact() {
    var c = S.contact || {};
    var box = $("contact-card");
    box.innerHTML = "";

    function row(label, value, isEmail) {
      if (!value) return;
      var d = el("div", isEmail ? "contact-row email" : "contact-row");
      d.appendChild(el("b", null, esc(label)));
      if (isEmail) {
        var a = el("a", null, esc(value));
        a.href = "mailto:" + value;
        d.appendChild(a);
        var btn = el("button", "copy-btn", "复制");
        btn.type = "button";
        btn.addEventListener("click", function () {
          var done = function () {
            var t = $("toast");
            t.classList.add("show");
            setTimeout(function () { t.classList.remove("show"); }, 1600);
          };
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(value).then(done, fallback);
          } else {
            fallback();
          }
          function fallback() {
            var ta = document.createElement("textarea");
            ta.value = value;
            ta.style.position = "fixed";
            ta.style.opacity = "0";
            document.body.appendChild(ta);
            ta.select();
            try { document.execCommand("copy"); done(); } catch (e) {}
            document.body.removeChild(ta);
          }
        });
        d.appendChild(btn);
      } else {
        d.appendChild(el("span", null, esc(value)));
      }
      box.appendChild(d);
    }

    row("邮箱", c.email, true);
    row("电话", c.phone, false);
    row("地址", c.address, false);
    if (c.note) box.appendChild(el("div", "contact-note", esc(c.note)));
  }

  /* ---------- 导航 + 空板块自动隐藏 ---------- */
  // 顺序即导航顺序；data 为空数组的板块会被隐藏
  var SECTIONS = [
    { id: "research", label: "学习方向", data: "research" },
    { id: "education", label: "教育背景", data: "education" },
    { id: "skills", label: "技能", data: "skills" },
    { id: "plan", label: "路线", data: "plan" },
    { id: "publications", label: "论文", data: "publications" },
    { id: "projects", label: "项目", data: "projects" },
    { id: "news", label: "近况", data: "news" },
    { id: "contact", label: "联系", data: null } // 联系方式恒显示
  ];

  var navMap = {}; // sectionId -> <a>

  function renderNav() {
    var nav = $("nav");
    nav.innerHTML = "";
    navMap = {};
    SECTIONS.forEach(function (s) {
      var sec = document.getElementById(s.id);
      var empty = s.data ? list(s.data).length === 0 : false;
      if (sec) sec.hidden = empty; // 有内容就显示，没内容就藏起来
      if (empty) return;
      var a = el("a", null, esc(s.label));
      a.href = "#" + s.id;
      nav.appendChild(a);
      navMap[s.id] = a;
    });
  }

  /* ---------- 主题切换 ---------- */
  function initTheme() {
    var btn = $("theme-btn");
    btn.addEventListener("click", function () {
      var now = document.documentElement.getAttribute("data-theme");
      var next = now === "dark" ? "light" : "dark";
      document.documentElement.setAttribute("data-theme", next);
      try { localStorage.setItem("theme", next); } catch (e) {}
    });
  }

  /* ---------- 顶部进度条 ---------- */
  function initProgress() {
    var bar = $("progress");
    if (!bar) return;
    function update() {
      var h = document.documentElement.scrollHeight - window.innerHeight;
      var p = h > 0 ? (window.scrollY || document.documentElement.scrollTop) / h : 0;
      bar.style.width = Math.min(100, Math.max(0, p * 100)) + "%";
    }
    window.addEventListener("scroll", update, { passive: true });
    window.addEventListener("resize", update);
    update();
  }

  /* ---------- 导航高亮（滚到哪个板块就亮哪个） ---------- */
  function initNavHighlight() {
    if (!("IntersectionObserver" in window)) return;
    var visible = {};
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { visible[e.target.id] = e.isIntersecting; });
      // 从上往下找第一个在视口里的板块
      var activeId = null;
      for (var i = 0; i < SECTIONS.length; i++) {
        if (visible[SECTIONS[i].id]) { activeId = SECTIONS[i].id; break; }
      }
      Object.keys(navMap).forEach(function (id) {
        navMap[id].classList.toggle("active", id === activeId);
      });
    }, { rootMargin: "-40% 0px -52% 0px", threshold: 0 });

    SECTIONS.forEach(function (s) {
      var sec = document.getElementById(s.id);
      if (sec && !sec.hidden) io.observe(sec);
    });
  }

  /* ---------- 滚动出现动画 ---------- */
  function initReveal() {
    var sections = document.querySelectorAll("main section");
    if (!("IntersectionObserver" in window)) return;
    var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce) return;

    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting) return;
        e.target.classList.add("in");
        io.unobserve(e.target);
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.06 });

    Array.prototype.forEach.call(sections, function (s) {
      // 首屏不做延迟，避免打开时闪一下
      if (s.classList.contains("hero")) return;
      s.classList.add("reveal");
      io.observe(s);
    });
  }

  /* ---------- 启动 ---------- */
  renderHead();
  renderResearch();
  renderEducation();
  renderSkills();
  renderEntries("plan", "plan-list");
  renderPubs();
  renderEntries("projects", "proj-list");
  renderNews();
  renderContact();
  renderNav();

  initTheme();
  initProgress();
  initNavHighlight();
  initReveal();
})();
