#!/usr/bin/env bash
# Solana DEVNET deneme meme token'ı — tamamen ücretsiz (test ağı, gerçek para yok)
# Kullanım:  bash deneme-token-devnet.sh "Token Adı" SEMBOL [arz] [metadata_uri]
# Örnek:     bash deneme-token-devnet.sh "Kızan Coin" KIZAN 1000000000
set -euo pipefail

NAME="${1:-Kızan Coin}"
SYMBOL="${2:-KIZAN}"
SUPPLY="${3:-1000000000}"          # 1 milyar (pump.fun standardı)
URI="${4:-https://example.com/metadata.json}"   # logo/açıklama JSON'u (sonradan güncellenebilir)
DECIMALS=6
TOKEN_2022="TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
KEYPAIR="$HOME/.config/solana/devnet.json"

say() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

# 1) Araçlar
if ! command -v solana >/dev/null; then
  say "Solana CLI kuruluyor (Anza)..."
  sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
  export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
fi
if ! command -v spl-token >/dev/null; then
  echo "spl-token bulunamadı. Kur:  cargo install spl-token-cli   (Rust gerekir: https://rustup.rs)"
  exit 1
fi

# 2) Devnet + cüzdan
say "Ağ: devnet"
solana config set --url https://api.devnet.solana.com >/dev/null
if [ ! -f "$KEYPAIR" ]; then
  say "Yeni devnet cüzdanı oluşturuluyor: $KEYPAIR"
  solana-keygen new --no-bip39-passphrase --outfile "$KEYPAIR"
fi
solana config set --keypair "$KEYPAIR" >/dev/null
WALLET=$(solana address)
echo "Cüzdan: $WALLET"

# 3) Test SOL (bedava)
BAL=$(solana balance | awk '{print $1}')
if awk "BEGIN{exit !($BAL < 0.5)}"; then
  say "Airdrop isteniyor (2 SOL test parası)..."
  solana airdrop 2 || {
    echo "Airdrop limitine takıldı. Tarayıcıdan al: https://faucet.solana.com  (adres: $WALLET)"
    echo "Sonra scripti tekrar çalıştır."; exit 1; }
fi
solana balance

# 4) Token (Token-2022, metadata zincir üstünde)
say "Token oluşturuluyor: $NAME ($SYMBOL)"
OUT=$(spl-token create-token --program-id "$TOKEN_2022" --enable-metadata \
        --decimals "$DECIMALS" --output json)
MINT=$(printf '%s' "$OUT" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("commandOutput",d).get("address"))')
echo "Mint adresi: $MINT"

spl-token initialize-metadata "$MINT" "$NAME" "$SYMBOL" "$URI"

# 5) Hesap aç + bas
say "$SUPPLY $SYMBOL basılıyor"
spl-token create-account "$MINT"
spl-token mint "$MINT" "$SUPPLY"

# 6) Mint yetkisini kapat = arz sabitlenir (alıcıların ilk baktığı güven işareti)
say "Mint yetkisi kalıcı olarak kapatılıyor"
spl-token authorize "$MINT" mint --disable

say "Bitti!"
spl-token balance "$MINT"
echo "Explorer: https://explorer.solana.com/address/$MINT?cluster=devnet"
echo "$NAME,$SYMBOL,$MINT,$(date -Iseconds)" >> "$HOME/deneme-tokenlarim.csv"
