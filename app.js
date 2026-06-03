const masks = {
  photo:
    "url(\"data:image/svg+xml,%3Csvg viewBox='0 0 24 24' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath fill='black' d='M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Zm1 14h14l-4.6-6-3.1 4-2.1-2.6L5 18Zm2.3-8.5a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6Z'/%3E%3C/svg%3E\")",
  video:
    "url(\"data:image/svg+xml,%3Csvg viewBox='0 0 24 24' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath fill='black' d='M4 5h11a2 2 0 0 1 2 2v1.5l4-2.4v11.8l-4-2.4V17a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z'/%3E%3C/svg%3E\")",
};

const thumbs = [
  "url('assets/thumb-01.jpg')",
  "url('assets/thumb-02.jpg')",
  "url('assets/thumb-03.jpg')",
  "url('assets/thumb-04.jpg')",
  "url('assets/thumb-05.jpg')",
  "url('assets/thumb-06.jpg')",
  "url('assets/thumb-07.jpg')",
  "url('assets/thumb-08.jpg')",
  "url('assets/thumb-09.jpg')",
  "url('assets/thumb-10.jpg')",
  "url('assets/thumb-11.jpg')",
];

const queueItems = [
  {
    id: 1,
    date: "今天",
    dateLabel: "2025-05-24",
    type: "photo",
    name: "IMG_20250524_103215.jpg",
    size: "4.2 MB",
    progress: 68,
    status: "uploading",
    thumb: 0,
  },
  {
    id: 2,
    date: "今天",
    dateLabel: "2025-05-24",
    type: "photo",
    name: "IMG_20250524_103102.jpg",
    size: "3.1 MB",
    progress: 42,
    status: "uploading",
    thumb: 1,
  },
  {
    id: 3,
    date: "今天",
    dateLabel: "2025-05-24",
    type: "photo",
    name: "IMG_20250524_102950.jpg",
    size: "5.6 MB",
    progress: 81,
    status: "uploading",
    thumb: 2,
  },
  {
    id: 4,
    date: "今天",
    dateLabel: "2025-05-24",
    type: "photo",
    name: "IMG_20250524_102820.jpg",
    size: "2.7 MB",
    progress: 100,
    status: "done",
    thumb: 3,
  },
  {
    id: 5,
    date: "今天",
    dateLabel: "2025-05-24",
    type: "video",
    name: "VID_20250524_102512.mp4",
    size: "32.4 MB",
    progress: 55,
    status: "uploading",
    thumb: 4,
  },
  {
    id: 6,
    date: "今天",
    dateLabel: "2025-05-24",
    type: "video",
    name: "VID_20250524_101945.mp4",
    size: "68.7 MB",
    progress: 26,
    status: "uploading",
    thumb: 5,
  },
  {
    id: 7,
    date: "今天",
    dateLabel: "2025-05-24",
    type: "video",
    name: "VID_20250524_101152.mp4",
    size: "125.8 MB",
    progress: 12,
    status: "uploading",
    thumb: 6,
  },
  {
    id: 8,
    date: "今天",
    dateLabel: "2025-05-24",
    type: "photo",
    name: "IMG_20250524_100832.jpg",
    size: "3.9 MB",
    progress: 0,
    status: "waiting",
    thumb: 7,
  },
  {
    id: 9,
    date: "昨天",
    dateLabel: "2025-05-23",
    type: "photo",
    name: "IMG_20250523_193512.jpg",
    size: "2.8 MB",
    progress: 100,
    status: "done",
    thumb: 8,
  },
  {
    id: 10,
    date: "昨天",
    dateLabel: "2025-05-23",
    type: "video",
    name: "VID_20250523_164208.mp4",
    size: "54.3 MB",
    progress: 100,
    status: "done",
    thumb: 9,
  },
  {
    id: 11,
    date: "昨天",
    dateLabel: "2025-05-23",
    type: "photo",
    name: "IMG_20250523_142033.jpg",
    size: "3.2 MB",
    progress: 0,
    status: "failed",
    thumb: 10,
  },
];

let activeScreen = "home";
let activeFilter = "all";
let isSyncing = true;
let toastTimer;

const statusLabels = {
  uploading: ["正在上传", ""],
  done: ["已完成", "done"],
  waiting: ["等待中", "waiting"],
  failed: ["上传失败", "failed"],
};

function el(selector) {
  return document.querySelector(selector);
}

function setScreen(screen) {
  activeScreen = screen;
  el("#home-screen").classList.toggle("screen-active", screen === "home");
  el("#queue-screen").classList.toggle("screen-active", screen === "queue");
  document.querySelectorAll(".nav-item").forEach((item) => {
    item.classList.toggle("selected", item.dataset.nav === screen);
  });
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function thumbMarkup(item) {
  const mediaMask = item.type === "video" ? masks.video : masks.photo;
  return `<span class="thumb ${item.type === "video" ? "video" : ""}" style="--thumb:${thumbs[item.thumb]};--media-mask:${mediaMask}"></span>`;
}

function renderRecentActivity() {
  const recent = queueItems.slice(0, 5);
  el("#recent-activity").innerHTML = recent
    .map((item) => {
      const detail =
        item.status === "failed"
          ? `<span class="item-detail failed">备份失败</span>`
          : item.status === "uploading"
            ? `<span class="item-detail">正在备份 ${item.progress}%</span>`
            : `<span class="item-detail">已备份 ${item.size}</span>`;
      const stateIcon =
        item.status === "failed"
          ? `<span class="row-action failed" aria-label="失败">!</span>`
          : item.status === "uploading"
            ? `<span class="mini-ring" aria-hidden="true"></span>`
            : `<span class="row-action success" aria-label="成功">✓</span>`;
      return `
        <button class="activity-item" type="button" data-action="show-queue">
          ${thumbMarkup(item)}
          <span class="item-main">
            <span class="file-name">${item.name}</span>
            ${detail}
          </span>
          <span class="item-time">
            <span>${item.id < 5 ? "14:32:" + (20 - item.id * 3) : "14:31:59"}</span>
            ${stateIcon}
          </span>
        </button>`;
    })
    .join("");
}

function queueItemMarkup(item) {
  const [label, chipClass] = statusLabels[item.status];
  const showProgress = item.status === "uploading";
  const action =
    item.status === "failed"
      ? `<button class="row-action failed" type="button" data-action="retry-one" data-id="${item.id}" aria-label="重试 ${item.name}"><span class="icon retry-icon"></span></button>`
      : item.status === "done"
        ? `<span class="row-action success" aria-label="已完成">✓</span>`
        : item.status === "waiting"
          ? `<span class="row-action" aria-label="等待中"><span class="icon clock-icon"></span></span>`
          : `<button class="row-action" type="button" data-action="pause-one" aria-label="暂停 ${item.name}"><span class="icon pause-icon"></span></button>`;

  return `
    <article class="queue-item" data-type="${item.type}" data-status="${item.status}">
      ${thumbMarkup(item)}
      <div class="item-main">
        <span class="file-name">${item.name}</span>
        <span class="item-detail">${item.size}</span>
        ${
          showProgress
            ? `<span class="progress-line"><span class="bar" style="--value:${item.progress}"><i></i></span><em>${item.progress}%</em></span>`
            : ""
        }
      </div>
      <span class="chip ${chipClass}">${label}</span>
      ${action}
    </article>`;
}

function renderQueue() {
  const filtered = queueItems.filter((item) => {
    if (activeFilter === "all") return true;
    if (activeFilter === "failed") return item.status === "failed";
    return item.type === activeFilter;
  });

  const groups = filtered.reduce((acc, item) => {
    const key = `${item.date}|${item.dateLabel}`;
    if (!acc[key]) acc[key] = [];
    acc[key].push(item);
    return acc;
  }, {});

  el("#queue-content").innerHTML =
    Object.keys(groups)
      .map((key) => {
        const [date, dateLabel] = key.split("|");
        return `
        <div class="date-heading">
          <strong>${date} <span>${dateLabel}（${groups[key].length}）</span></strong>
          <span>${date === "今天" ? "正在上传 8 · 42.3 MB/s" : ""}</span>
        </div>
        ${groups[key].map(queueItemMarkup).join("")}`;
      })
      .join("") ||
    `<div class="empty-state">
      <strong>没有匹配的任务</strong>
      <span>换个筛选条件，或稍后等待新的相册文件加入队列。</span>
    </div>`;
}

function updateSyncState() {
  el("#sync-state-label").textContent = isSyncing ? "正在同步" : "已暂停";
  el("#sync-percent").textContent = isSyncing ? "86%" : "暂停";
  el("#speed-label").textContent = isSyncing ? "16.8 MB/s" : "0 MB/s";
  el("#queue-state").textContent = isSyncing ? "正在上传" : "已暂停";
  const pauseButton = el("#pause-button");
  pauseButton.classList.toggle("active", isSyncing);
  pauseButton.querySelector("span:last-child").textContent = isSyncing
    ? "暂停同步"
    : "继续同步";
  pauseButton.querySelector(".icon").classList.toggle("pause-icon", isSyncing);
  pauseButton.querySelector(".icon").classList.toggle("play-icon", !isSyncing);
}

function showToast(message) {
  window.clearTimeout(toastTimer);
  const toast = el("#toast");
  toast.textContent = message;
  toast.classList.add("visible");
  toastTimer = window.setTimeout(() => toast.classList.remove("visible"), 2200);
}

function openDrawer(kind) {
  const content = {
    target: `
      <h2 class="drawer-title">选择备份目标</h2>
      <div class="option-list">
        <button class="option-row" type="button" data-action="select-option">
          <span class="target-icon nas-icon compact"></span>
          <span><strong>家庭 NAS</strong><small>192.168.1.100 · PhotosBackup · 当前使用</small></span>
          <span class="row-action success">✓</span>
        </button>
        <button class="option-row" type="button" data-action="select-option">
          <span class="icon drive-icon"></span>
          <span><strong>客厅电脑</strong><small>192.168.1.23 · Windows 11 · 推荐</small></span>
          <span class="chevron"></span>
        </button>
        <button class="option-row" type="button" data-action="manual-address">
          <span class="icon folder-icon"></span>
          <span><strong>手动输入地址</strong><small>输入 IP 地址、主机名或共享文件夹路径</small></span>
          <span class="chevron"></span>
        </button>
      </div>`,
    albums: `
      <h2 class="drawer-title">选择相册范围</h2>
      <div class="option-list">
        <button class="option-row" type="button" data-action="select-option">
          <span class="icon success-icon"></span>
          <span><strong>相机胶卷</strong><small>照片和视频 · 1,714 个文件 · 当前同步</small></span>
          <span class="switch" aria-hidden="true"></span>
        </button>
        <button class="option-row" type="button" data-action="select-option">
          <span class="icon album-icon"></span>
          <span><strong>屏幕截图</strong><small>未启用 · 可单独加入备份范围</small></span>
          <span class="chevron"></span>
        </button>
        <button class="option-row" type="button" data-action="select-option">
          <span class="icon album-icon"></span>
          <span><strong>视频</strong><small>已包含在相机胶卷规则内</small></span>
          <span class="row-action success">✓</span>
        </button>
      </div>`,
    rules: `
      <h2 class="drawer-title">同步规则</h2>
      <div class="option-list">
        <button class="option-row" type="button" data-action="toggle-option">
          <span class="icon wifi-icon"></span>
          <span><strong>仅在 Wi-Fi 下同步</strong><small>避免使用移动数据上传大文件</small></span>
          <span class="switch" aria-hidden="true"></span>
        </button>
        <button class="option-row" type="button" data-action="toggle-option">
          <span class="icon gauge-icon"></span>
          <span><strong>充电时优先同步</strong><small>电量低于 20% 时暂停备份</small></span>
          <span class="switch" aria-hidden="true"></span>
        </button>
        <button class="option-row" type="button" data-action="select-option">
          <span class="icon shield-icon"></span>
          <span><strong>跳过已存在文件</strong><small>按文件大小、拍摄时间和名称判断重复</small></span>
          <span class="row-action success">✓</span>
        </button>
      </div>`,
    settings: `
      <h2 class="drawer-title">设置</h2>
      <div class="option-list">
        <button class="option-row" type="button" data-action="open-target">
          <span class="icon drive-icon"></span>
          <span><strong>备份目标</strong><small>家庭 NAS / PhotosBackup</small></span>
          <span class="chevron"></span>
        </button>
        <button class="option-row" type="button" data-action="open-albums">
          <span class="icon album-icon"></span>
          <span><strong>相册范围</strong><small>相机胶卷中的照片和视频</small></span>
          <span class="chevron"></span>
        </button>
        <button class="option-row" type="button" data-action="open-rules">
          <span class="icon shield-icon"></span>
          <span><strong>同步规则</strong><small>Wi-Fi、充电策略、重复文件处理</small></span>
          <span class="chevron"></span>
        </button>
      </div>`,
  };

  el("#drawer-content").innerHTML = content[kind] || content.settings;
  el("#drawer").classList.add("open");
  el("#drawer").setAttribute("aria-hidden", "false");
}

function closeDrawer() {
  el("#drawer").classList.remove("open");
  el("#drawer").setAttribute("aria-hidden", "true");
}

function retryFailed() {
  const failed = queueItems.find((item) => item.status === "failed");
  if (!failed) {
    showToast("当前没有失败任务");
    return;
  }
  failed.status = "waiting";
  failed.progress = 0;
  renderQueue();
  renderRecentActivity();
  showToast("已将失败任务加入重试队列");
}

function handleAction(action, target) {
  if (!action) return;
  if (action === "show-queue") setScreen("queue");
  if (action === "toggle-sync") {
    isSyncing = !isSyncing;
    updateSyncState();
    showToast(isSyncing ? "同步已继续" : "同步已暂停");
  }
  if (action === "retry-failed" || action === "retry-one") retryFailed();
  if (action === "open-target") openDrawer("target");
  if (action === "open-albums") openDrawer("albums");
  if (action === "open-rules") openDrawer("rules");
  if (action === "open-settings") openDrawer("settings");
  if (action === "close-drawer") closeDrawer();
  if (action === "select-option") {
    closeDrawer();
    showToast("设置已更新");
  }
  if (action === "toggle-option") showToast("规则已切换");
  if (action === "manual-address") showToast("手动地址输入将在下一步原型中展开");
  if (action === "pause-one") showToast("单个任务已暂停");
}

document.addEventListener("click", (event) => {
  const actionTarget = event.target.closest("[data-action]");
  const navTarget = event.target.closest("[data-nav]");
  const filterTarget = event.target.closest("[data-filter]");

  if (navTarget) {
    setScreen(navTarget.dataset.nav);
    return;
  }

  if (filterTarget) {
    activeFilter = filterTarget.dataset.filter;
    document.querySelectorAll(".filter-tab").forEach((tab) => {
      tab.classList.toggle("selected", tab === filterTarget);
    });
    renderQueue();
    return;
  }

  if (actionTarget) handleAction(actionTarget.dataset.action, actionTarget);
});

renderRecentActivity();
renderQueue();
updateSyncState();
