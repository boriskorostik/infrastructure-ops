const form = document.querySelector("#playerForm");
const nameInput = document.querySelector("#nameInput");
const chipsInput = document.querySelector("#chipsInput");
const playersEl = document.querySelector("#players");
const statusEl = document.querySelector("#status");
const totalChipsEl = document.querySelector("#totalChips");
const myChipsEl = document.querySelector("#myChips");
const resetMineBtn = document.querySelector("#resetMineBtn");
const rebuyBtn = document.querySelector("#rebuyBtn");
const scoreboardEl = document.querySelector("#scoreboard");
const template = document.querySelector("#playerTemplate");
const scoreTemplate = document.querySelector("#scoreTemplate");
const playerNames = ["Александр", "Борис", "Даня", "Елена", "Леонид"];
const placePoints = [12, 8, 5, 3, 1];

const savedName = localStorage.getItem("pokerPlayerName") === "Даниил"
  ? "Даня"
  : localStorage.getItem("pokerPlayerName") || "";
nameInput.value = savedName;
let isEditingChips = false;

function formatNumber(value) {
  return new Intl.NumberFormat("ru-RU").format(value);
}

function formatTime(ms) {
  if (!ms) return "еще не обновлялся";
  return new Intl.DateTimeFormat("ru-RU", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit"
  }).format(new Date(ms));
}

function normalizeChips(value) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) return 0;
  return Math.max(0, Math.min(parsed, 999999999));
}

async function request(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error || "Ошибка сервера");
  }
  return data;
}

function render(state) {
  const players = state.players || [];
  const knockouts = state.knockouts || {};
  const myName = nameInput.value.trim().toLowerCase();
  const myPlayer = players.find((player) => player.name.toLowerCase() === myName);
  const total = players.reduce((sum, player) => sum + player.chips, 0);
  totalChipsEl.textContent = `${formatNumber(total)} фишек`;
  myChipsEl.textContent = formatNumber(myPlayer?.chips || 0);
  statusEl.textContent = `Обновлено: ${formatTime(state.updatedAt)}`;

  playersEl.replaceChildren();
  if (players.length === 0) {
    const empty = document.createElement("div");
    empty.className = "empty";
    empty.textContent = "Пока никто не записал фишки.";
    playersEl.append(empty);
    renderScoreboard(players, knockouts);
    return;
  }

  for (const [index, player] of players.entries()) {
    const node = template.content.firstElementChild.cloneNode(true);
    node.querySelector(".rank").textContent = index + 1;
    node.querySelector("strong").textContent = player.name;
    node.querySelector("small").textContent = `обновлено ${formatTime(player.updatedAt)}`;
    node.querySelector(".chips").textContent = formatNumber(player.chips);
    if (player.name.toLowerCase() === myName) {
      node.classList.add("mine");
      if (!isEditingChips && document.activeElement !== chipsInput) {
        chipsInput.value = player.chips;
      }
    }
    playersEl.append(node);
  }

  renderScoreboard(players, knockouts);
}

function renderScoreboard(players, knockouts) {
  const chipsByName = Object.fromEntries(players.map((player) => [player.name, player.chips]));
  const ranked = playerNames
    .map((name) => ({
      name,
      chips: chipsByName[name] || 0,
      knockouts: Number(knockouts[name] || 0)
    }))
    .sort((a, b) => b.chips - a.chips || a.name.localeCompare(b.name, "ru"));

  scoreboardEl.replaceChildren();
  for (const [index, row] of ranked.entries()) {
    const placeScore = row.chips > 0 ? placePoints[index] || 0 : 0;
    const knockoutScore = row.knockouts * 3;
    const totalScore = placeScore + knockoutScore;
    const node = scoreTemplate.content.firstElementChild.cloneNode(true);
    node.querySelector(".score-place").textContent = index + 1;
    node.querySelector("strong").textContent = row.name;
    node.querySelector("small").textContent =
      `${formatNumber(row.chips)} фишек · место ${placeScore} · выбивания ${knockoutScore}`;
    node.querySelector(".knockout-controls").dataset.name = row.name;
    node.querySelector(".knockout-controls span").textContent = row.knockouts;
    node.querySelector(".score-total").textContent = totalScore;
    scoreboardEl.append(node);
  }
}

async function loadState() {
  try {
    const state = await request("/api/state");
    render(state);
  } catch (error) {
    statusEl.textContent = `Не удалось обновить: ${error.message}`;
  }
}

async function savePlayer() {
  const name = nameInput.value.trim();
  const chips = normalizeChips(chipsInput.value);
  if (!name) {
    nameInput.focus();
    return;
  }

  localStorage.setItem("pokerPlayerName", name);
  chipsInput.value = chips;
  const state = await request("/api/player", {
    method: "POST",
    body: JSON.stringify({ name, chips })
  });
  render(state);
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    isEditingChips = false;
    await savePlayer();
  } catch (error) {
    statusEl.textContent = error.message;
  }
});

document.querySelectorAll("[data-delta]").forEach((button) => {
  button.addEventListener("click", async () => {
    isEditingChips = false;
    chipsInput.value = normalizeChips(chipsInput.value) + Number(button.dataset.delta);
    chipsInput.value = normalizeChips(chipsInput.value);
    try {
      await savePlayer();
    } catch (error) {
      statusEl.textContent = error.message;
    }
  });
});

rebuyBtn.addEventListener("click", async () => {
  const name = nameInput.value.trim();
  if (!name) {
    statusEl.textContent = "Выберите себя";
    return;
  }
  isEditingChips = false;
  chipsInput.value = "1500";
  try {
    await savePlayer();
  } catch (error) {
    statusEl.textContent = error.message;
  }
});

resetMineBtn.addEventListener("click", async () => {
  const name = nameInput.value.trim();
  if (!name) {
    statusEl.textContent = "Выберите себя";
    return;
  }
  if (!confirm("Сбросить только ваши фишки до 0?")) return;
  try {
    localStorage.setItem("pokerPlayerName", name);
    const state = await request("/api/reset-my", {
      method: "POST",
      body: JSON.stringify({ name })
    });
    chipsInput.value = "0";
    render(state);
  } catch (error) {
    statusEl.textContent = error.message;
  }
});

scoreboardEl.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-ko]");
  if (!button) return;

  const controls = button.closest(".knockout-controls");
  const name = controls?.dataset.name;
  if (!name) return;

  try {
    const state = await request("/api/knockout", {
      method: "POST",
      body: JSON.stringify({ name, delta: Number(button.dataset.ko) })
    });
    render(state);
  } catch (error) {
    statusEl.textContent = error.message;
  }
});

nameInput.addEventListener("change", () => {
  localStorage.setItem("pokerPlayerName", nameInput.value.trim());
  loadState();
});

chipsInput.addEventListener("input", () => {
  isEditingChips = true;
});

chipsInput.addEventListener("blur", () => {
  chipsInput.value = normalizeChips(chipsInput.value);
});

loadState();
setInterval(loadState, 2000);
