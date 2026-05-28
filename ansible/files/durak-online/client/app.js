const socket = io();

const els = {
  status: document.querySelector("#status"),
  roomBadge: document.querySelector("#roomBadge"),
  lobby: document.querySelector("#lobby"),
  nameInput: document.querySelector("#nameInput"),
  codeInput: document.querySelector("#codeInput"),
  createBtn: document.querySelector("#createBtn"),
  joinBtn: document.querySelector("#joinBtn"),
  startBtn: document.querySelector("#startBtn"),
  restartBtn: document.querySelector("#restartBtn"),
  players: document.querySelector("#players"),
  deck: document.querySelector("#deck"),
  trump: document.querySelector("#trump"),
  turn: document.querySelector("#turn"),
  table: document.querySelector("#table"),
  hand: document.querySelector("#hand"),
  passBtn: document.querySelector("#passBtn"),
  takeBtn: document.querySelector("#takeBtn")
};

const suitSymbols = {
  clubs: "♣",
  diamonds: "♦",
  hearts: "♥",
  spades: "♠"
};

let state = null;
let selectedDefenseCardId = null;

els.createBtn.addEventListener("click", () => {
  socket.emit("createRoom", { name: playerName() }, handleReply);
});

els.joinBtn.addEventListener("click", () => {
  socket.emit("joinRoom", { name: playerName(), code: els.codeInput.value }, handleReply);
});

els.startBtn.addEventListener("click", () => {
  socket.emit("startGame", handleReply);
});

els.restartBtn.addEventListener("click", () => {
  socket.emit("restart", handleReply);
});

els.passBtn.addEventListener("click", () => {
  socket.emit("pass", handleReply);
});

els.takeBtn.addEventListener("click", () => {
  socket.emit("take", handleReply);
});

socket.on("state", (nextState) => {
  state = nextState;
  selectedDefenseCardId = null;
  render();
});

function playerName() {
  return els.nameInput.value.trim() || localStorage.getItem("durakName") || "Игрок";
}

function handleReply(reply) {
  if (!reply?.ok) {
    setStatus(reply?.error || "Ошибка", true);
    return;
  }
  if (reply.code) els.codeInput.value = reply.code;
  localStorage.setItem("durakName", playerName());
}

function setStatus(text, isError = false) {
  els.status.textContent = text;
  els.status.className = isError ? "danger" : "";
}

function render() {
  if (!state) return;
  els.lobby.classList.toggle("hidden", state.status !== "lobby");
  els.roomBadge.textContent = `Комната: ${state.code}`;
  setStatus(state.message || "Готово");
  renderPlayers();
  renderTable();
  renderHand();
  renderControls();
}

function renderPlayers() {
  els.players.innerHTML = "";
  state.players.forEach((player) => {
    const row = document.createElement("div");
    row.className = "player";
    const role = roleFor(player.id);
    row.innerHTML = `
      <div>
        <strong>${escapeHtml(player.name)}${player.id === state.you?.id ? " (вы)" : ""}</strong>
        <small>${role}${player.out ? " · вышел" : ""}${player.connected ? "" : " · offline"}</small>
      </div>
      <span>${player.cardCount}</span>
    `;
    els.players.append(row);
  });
}

function renderTable() {
  els.deck.textContent = `Колода ${state.deckCount}`;
  els.trump.textContent = state.trumpCard ? `${suitSymbols[state.trump]} козырь ${state.trumpCard.rank}` : "Козырь";
  els.turn.textContent = turnText();
  els.table.innerHTML = "";

  if (state.table.length === 0) {
    els.table.innerHTML = '<div class="empty">Стол пуст</div>';
    return;
  }

  state.table.forEach((pair) => {
    const wrap = document.createElement("div");
    wrap.className = "pair";
    wrap.append(cardElement(pair.attack));
    if (pair.defense) {
      wrap.append(cardElement(pair.defense));
    } else {
      const slot = document.createElement("button");
      slot.className = "secondary";
      slot.textContent = "Покрыть";
      slot.disabled = !canDefend() || !selectedDefenseCardId;
      slot.addEventListener("click", () => {
        socket.emit("defend", { attackCardId: pair.attack.id, cardId: selectedDefenseCardId }, handleReply);
      });
      wrap.append(slot);
    }
    els.table.append(wrap);
  });
}

function renderHand() {
  els.hand.innerHTML = "";
  const hand = state.you?.hand || [];
  if (hand.length === 0) {
    els.hand.innerHTML = '<div class="empty">Карт нет</div>';
    return;
  }

  hand.forEach((card) => {
    const item = cardElement(card);
    const button = document.createElement("button");
    button.setAttribute("aria-label", `${card.rank} ${card.suit}`);
    item.innerHTML = "";
    button.innerHTML = cardMarkup(card);
    item.append(button);

    if (canAttack()) {
      item.classList.add("selectable");
      button.addEventListener("click", () => socket.emit("attack", { cardId: card.id }, handleReply));
    } else if (canDefend()) {
      item.classList.toggle("selectable", selectedDefenseCardId === card.id);
      button.addEventListener("click", () => {
        selectedDefenseCardId = selectedDefenseCardId === card.id ? null : card.id;
        render();
      });
    }
    els.hand.append(item);
  });
}

function renderControls() {
  const isHost = state.you?.id === state.hostId;
  els.startBtn.classList.toggle("hidden", state.status !== "lobby" || !isHost);
  els.restartBtn.classList.toggle("hidden", state.status !== "finished" || !isHost);
  els.passBtn.classList.toggle("hidden", !canPass());
  els.takeBtn.classList.toggle("hidden", !canTake());
}

function cardElement(card) {
  const div = document.createElement("div");
  div.className = `card ${card.suit === "hearts" || card.suit === "diamonds" ? "red" : ""}`;
  div.innerHTML = cardMarkup(card);
  return div;
}

function cardMarkup(card) {
  const suit = suitSymbols[card.suit];
  return `
    <div>${card.rank}${suit}</div>
    <div class="middle">${suit}</div>
    <div class="bottom">${card.rank}${suit}</div>
  `;
}

function roleFor(playerId) {
  if (state.status === "finished" && !state.winnerIds.includes(playerId)) return "дурак";
  if (playerId === state.attackerId) return "атака";
  if (playerId === state.defenderId) return "защита";
  return "ожидает";
}

function turnText() {
  if (state.status === "lobby") return "Лобби";
  if (state.status === "finished") return "Игра окончена";
  if (state.currentTurn === "attack") return "Ход атаки";
  if (state.currentTurn === "defense") return "Ход защиты";
  return "Ожидание";
}

function canAttack() {
  return state.status === "playing" && state.currentTurn === "attack" && state.you?.id === state.attackerId;
}

function canDefend() {
  return state.status === "playing" && state.currentTurn === "defense" && state.you?.id === state.defenderId;
}

function canPass() {
  return canAttack() && state.table.length > 0 && state.table.every((pair) => pair.defense);
}

function canTake() {
  return state.status === "playing" && state.you?.id === state.defenderId && state.table.length > 0;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => {
    return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[char];
  });
}

els.nameInput.value = localStorage.getItem("durakName") || "";
