const path = require("path");
const express = require("express");
const http = require("http");
const { Server } = require("socket.io");

const PORT = process.env.PORT || 3000;
const MAX_PLAYERS = 6;
const MIN_PLAYERS = 2;
const HAND_SIZE = 6;
const SUITS = ["clubs", "diamonds", "hearts", "spades"];
const RANKS = ["6", "7", "8", "9", "10", "J", "Q", "K", "A"];
const RANK_VALUE = Object.fromEntries(RANKS.map((rank, index) => [rank, index]));

const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.static(path.join(__dirname, "../client")));

const rooms = new Map();

function makeRoomCode() {
  let code;
  do {
    code = Math.random().toString(36).slice(2, 7).toUpperCase();
  } while (rooms.has(code));
  return code;
}

function makeDeck() {
  const deck = [];
  for (const suit of SUITS) {
    for (const rank of RANKS) {
      deck.push({ id: `${rank}-${suit}`, rank, suit });
    }
  }
  return deck;
}

function shuffle(cards) {
  const deck = [...cards];
  for (let i = deck.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}

function createRoom(hostId, hostName) {
  const code = makeRoomCode();
  const room = {
    code,
    hostId,
    status: "lobby",
    players: [
      {
        id: hostId,
        name: hostName,
        hand: [],
        connected: true,
        out: false
      }
    ],
    deck: [],
    trump: null,
    trumpCard: null,
    table: [],
    attackerIndex: 0,
    defenderIndex: 1,
    currentTurn: "attack",
    discardCount: 0,
    winnerIds: [],
    message: "Комната создана"
  };
  rooms.set(code, room);
  return room;
}

function publicPlayer(player) {
  return {
    id: player.id,
    name: player.name,
    cardCount: player.hand.length,
    connected: player.connected,
    out: player.out
  };
}

function visibleState(room, viewerId) {
  const viewer = room.players.find((player) => player.id === viewerId);
  return {
    code: room.code,
    hostId: room.hostId,
    status: room.status,
    players: room.players.map(publicPlayer),
    you: viewer
      ? {
          id: viewer.id,
          name: viewer.name,
          hand: sortHand(viewer.hand, room.trump)
        }
      : null,
    deckCount: room.deck.length,
    trump: room.trump,
    trumpCard: room.trumpCard,
    table: room.table,
    attackerId: room.players[room.attackerIndex]?.id,
    defenderId: room.players[room.defenderIndex]?.id,
    currentTurn: room.currentTurn,
    discardCount: room.discardCount,
    winnerIds: room.winnerIds,
    message: room.message
  };
}

function broadcastRoom(room) {
  for (const player of room.players) {
    io.to(player.id).emit("state", visibleState(room, player.id));
  }
}

function sortHand(hand, trump) {
  return [...hand].sort((a, b) => {
    if (a.suit === trump && b.suit !== trump) return 1;
    if (a.suit !== trump && b.suit === trump) return -1;
    if (a.suit !== b.suit) return a.suit.localeCompare(b.suit);
    return RANK_VALUE[a.rank] - RANK_VALUE[b.rank];
  });
}

function findRoomBySocket(socketId) {
  for (const room of rooms.values()) {
    if (room.players.some((player) => player.id === socketId)) {
      return room;
    }
  }
  return null;
}

function drawToSix(room, orderedPlayers) {
  for (const player of orderedPlayers) {
    while (!player.out && player.hand.length < HAND_SIZE && room.deck.length > 0) {
      player.hand.push(room.deck.shift());
    }
  }
}

function activePlayers(room) {
  return room.players.filter((player) => !player.out);
}

function nextActiveIndex(room, fromIndex) {
  if (activePlayers(room).length <= 1) return -1;
  for (let step = 1; step <= room.players.length; step += 1) {
    const index = (fromIndex + step) % room.players.length;
    if (!room.players[index].out) return index;
  }
  return -1;
}

function markFinishedPlayers(room) {
  for (const player of room.players) {
    if (!player.out && player.hand.length === 0 && room.deck.length === 0) {
      player.out = true;
      room.winnerIds.push(player.id);
    }
  }
}

function finishIfNeeded(room) {
  const alive = activePlayers(room);
  if (room.status === "playing" && alive.length <= 1) {
    room.status = "finished";
    room.currentTurn = "finished";
    if (alive[0]) {
      room.message = `${alive[0].name} остался без победы. Игра окончена.`;
    } else {
      room.message = "Игра окончена.";
    }
    return true;
  }
  return false;
}

function cardBeats(defense, attack, trump) {
  if (defense.suit === attack.suit) {
    return RANK_VALUE[defense.rank] > RANK_VALUE[attack.rank];
  }
  return defense.suit === trump && attack.suit !== trump;
}

function tableRanks(room) {
  return new Set(
    room.table.flatMap((pair) => [pair.attack.rank, pair.defense?.rank].filter(Boolean))
  );
}

function removeCard(player, cardId) {
  const index = player.hand.findIndex((card) => card.id === cardId);
  if (index === -1) return null;
  const [card] = player.hand.splice(index, 1);
  return card;
}

function startGame(room) {
  room.status = "playing";
  room.deck = shuffle(makeDeck());
  room.trumpCard = room.deck[room.deck.length - 1];
  room.trump = room.trumpCard.suit;
  room.table = [];
  room.discardCount = 0;
  room.winnerIds = [];
  room.players.forEach((player) => {
    player.hand = [];
    player.out = false;
  });

  for (let i = 0; i < HAND_SIZE; i += 1) {
    for (const player of room.players) {
      player.hand.push(room.deck.shift());
    }
  }

  let lowestTrumpIndex = -1;
  let lowestTrumpValue = Infinity;
  room.players.forEach((player, index) => {
    for (const card of player.hand) {
      if (card.suit === room.trump && RANK_VALUE[card.rank] < lowestTrumpValue) {
        lowestTrumpValue = RANK_VALUE[card.rank];
        lowestTrumpIndex = index;
      }
    }
  });

  room.attackerIndex = lowestTrumpIndex === -1 ? 0 : lowestTrumpIndex;
  room.defenderIndex = nextActiveIndex(room, room.attackerIndex);
  room.currentTurn = "attack";
  room.message = `Ходит ${room.players[room.attackerIndex].name}`;
}

function afterSuccessfulDefense(room) {
  const attacker = room.players[room.attackerIndex];
  const defender = room.players[room.defenderIndex];
  room.discardCount += room.table.length * 2;
  room.table = [];

  drawToSix(room, [
    attacker,
    ...room.players.filter((player) => player.id !== attacker.id && player.id !== defender.id),
    defender
  ]);
  markFinishedPlayers(room);
  if (finishIfNeeded(room)) return;

  room.attackerIndex = room.players.findIndex((player) => player.id === defender.id && !player.out);
  if (room.attackerIndex === -1) {
    room.attackerIndex = nextActiveIndex(room, room.defenderIndex);
  }
  room.defenderIndex = nextActiveIndex(room, room.attackerIndex);
  room.currentTurn = "attack";
  room.message = `Отбой. Теперь ходит ${room.players[room.attackerIndex].name}`;
}

function defenderTakes(room) {
  const attacker = room.players[room.attackerIndex];
  const defender = room.players[room.defenderIndex];
  const taken = room.table.flatMap((pair) => [pair.attack, pair.defense].filter(Boolean));
  defender.hand.push(...taken);
  room.table = [];

  drawToSix(room, [
    attacker,
    ...room.players.filter((player) => player.id !== attacker.id && player.id !== defender.id),
    defender
  ]);
  markFinishedPlayers(room);
  if (finishIfNeeded(room)) return;

  room.attackerIndex = nextActiveIndex(room, room.defenderIndex);
  room.defenderIndex = nextActiveIndex(room, room.attackerIndex);
  room.currentTurn = "attack";
  room.message = `${defender.name} взял карты. Ходит ${room.players[room.attackerIndex].name}`;
}

io.on("connection", (socket) => {
  socket.on("createRoom", ({ name }, reply) => {
    const room = createRoom(socket.id, cleanName(name));
    socket.join(room.code);
    reply?.({ ok: true, code: room.code });
    broadcastRoom(room);
  });

  socket.on("joinRoom", ({ code, name }, reply) => {
    const room = rooms.get(String(code || "").trim().toUpperCase());
    if (!room) return reply?.({ ok: false, error: "Комната не найдена" });
    if (room.status !== "lobby") return reply?.({ ok: false, error: "Игра уже началась" });
    if (room.players.length >= MAX_PLAYERS) return reply?.({ ok: false, error: "Комната заполнена" });

    room.players.push({
      id: socket.id,
      name: cleanName(name),
      hand: [],
      connected: true,
      out: false
    });
    socket.join(room.code);
    room.message = `${cleanName(name)} подключился`;
    reply?.({ ok: true, code: room.code });
    broadcastRoom(room);
  });

  socket.on("startGame", (reply) => {
    const room = findRoomBySocket(socket.id);
    if (!room) return reply?.({ ok: false, error: "Сначала создайте или войдите в комнату" });
    if (room.hostId !== socket.id) return reply?.({ ok: false, error: "Начать игру может только создатель" });
    if (room.players.length < MIN_PLAYERS) return reply?.({ ok: false, error: "Нужно минимум 2 игрока" });
    startGame(room);
    reply?.({ ok: true });
    broadcastRoom(room);
  });

  socket.on("attack", ({ cardId }, reply) => {
    const room = findRoomBySocket(socket.id);
    if (!room || room.status !== "playing") return reply?.({ ok: false, error: "Игра не идет" });
    if (room.players[room.attackerIndex]?.id !== socket.id) {
      return reply?.({ ok: false, error: "Сейчас ходит другой игрок" });
    }

    const attacker = room.players[room.attackerIndex];
    const defender = room.players[room.defenderIndex];
    if (room.table.length >= defender.hand.length) {
      return reply?.({ ok: false, error: "Защитнику нельзя подкинуть больше карт, чем у него в руке" });
    }

    const card = removeCard(attacker, cardId);
    if (!card) return reply?.({ ok: false, error: "Карты нет в руке" });

    if (room.table.length > 0 && !tableRanks(room).has(card.rank)) {
      attacker.hand.push(card);
      return reply?.({ ok: false, error: "Подкидывать можно только совпадающий ранг" });
    }

    room.table.push({ attack: card, defense: null });
    room.currentTurn = "defense";
    room.message = `${attacker.name} атакует. Защищается ${defender.name}`;
    reply?.({ ok: true });
    broadcastRoom(room);
  });

  socket.on("defend", ({ attackCardId, cardId }, reply) => {
    const room = findRoomBySocket(socket.id);
    if (!room || room.status !== "playing") return reply?.({ ok: false, error: "Игра не идет" });
    if (room.players[room.defenderIndex]?.id !== socket.id) {
      return reply?.({ ok: false, error: "Сейчас защищается другой игрок" });
    }

    const pair = room.table.find((item) => item.attack.id === attackCardId && !item.defense);
    if (!pair) return reply?.({ ok: false, error: "Эту карту уже покрыли" });

    const defender = room.players[room.defenderIndex];
    const card = removeCard(defender, cardId);
    if (!card) return reply?.({ ok: false, error: "Карты нет в руке" });

    if (!cardBeats(card, pair.attack, room.trump)) {
      defender.hand.push(card);
      return reply?.({ ok: false, error: "Эта карта не бьет атаку" });
    }

    pair.defense = card;
    room.currentTurn = room.table.every((item) => item.defense) ? "attack" : "defense";
    room.message = room.currentTurn === "attack" ? "Защита успешна. Можно подкинуть или отправить в отбой." : "Защита продолжается.";
    reply?.({ ok: true });
    broadcastRoom(room);
  });

  socket.on("pass", (reply) => {
    const room = findRoomBySocket(socket.id);
    if (!room || room.status !== "playing") return reply?.({ ok: false, error: "Игра не идет" });
    if (room.players[room.attackerIndex]?.id !== socket.id) {
      return reply?.({ ok: false, error: "Отбой объявляет атакующий" });
    }
    if (room.table.length === 0 || room.table.some((pair) => !pair.defense)) {
      return reply?.({ ok: false, error: "Отбой возможен только когда все карты побиты" });
    }
    afterSuccessfulDefense(room);
    reply?.({ ok: true });
    broadcastRoom(room);
  });

  socket.on("take", (reply) => {
    const room = findRoomBySocket(socket.id);
    if (!room || room.status !== "playing") return reply?.({ ok: false, error: "Игра не идет" });
    if (room.players[room.defenderIndex]?.id !== socket.id) {
      return reply?.({ ok: false, error: "Взять карты может только защитник" });
    }
    if (room.table.length === 0) return reply?.({ ok: false, error: "На столе нет карт" });
    defenderTakes(room);
    reply?.({ ok: true });
    broadcastRoom(room);
  });

  socket.on("restart", (reply) => {
    const room = findRoomBySocket(socket.id);
    if (!room) return reply?.({ ok: false, error: "Комната не найдена" });
    if (room.hostId !== socket.id) return reply?.({ ok: false, error: "Перезапуск доступен создателю" });
    startGame(room);
    reply?.({ ok: true });
    broadcastRoom(room);
  });

  socket.on("disconnect", () => {
    const room = findRoomBySocket(socket.id);
    if (!room) return;
    const player = room.players.find((item) => item.id === socket.id);
    if (player) player.connected = false;
    room.message = `${player?.name || "Игрок"} отключился`;
    broadcastRoom(room);
  });
});

function cleanName(name) {
  const value = String(name || "").trim();
  return value.slice(0, 24) || "Игрок";
}

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Durak Online server is running on http://0.0.0.0:${PORT}`);
});
