# 🍎 Como Configurar os Secrets para Build iOS

Este guia explica como obter e configurar cada secret necessário para
o workflow de build iOS do Green Express via GitHub Actions.

---

## 📋 Lista de Secrets Necessários

| Secret | Descrição | Como Obter |
|--------|-----------|------------|
| `BUILD_CERTIFICATE_BASE64` | Certificado .p12 codificado em base64 | Ver Passo 1 |
| `P12_PASSWORD` | Senha do certificado .p12 | Definida por você ao exportar |
| `BUILD_PROVISION_PROFILE_BASE64` | Provisioning Profile em base64 | Ver Passo 2 |
| `KEYCHAIN_PASSWORD` | Senha temporária (qualquer valor) | Ex: `temp123456` |
| `APPSTORE_API_KEY_ID` | ID da API Key do App Store Connect | Ver Passo 3 |
| `APPSTORE_API_ISSUER_ID` | Issuer ID do App Store Connect | Ver Passo 3 |
| `APPSTORE_API_PRIVATE_KEY` | Chave privada .p8 (conteúdo) | Ver Passo 3 |

---

## Passo 1: Criar Certificado de Distribuição (.p12)

### No Mac:
1. Abra **Keychain Access** → Menu **Certificate Assistant** → **Request a Certificate from a Certificate Authority**
2. Preencha seu email, nome, e salve em disco
3. Acesse [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates/add)
4. Clique em **+** → Selecione **Apple Distribution**
5. Faça upload do CSR gerado no passo 2
6. Baixe o certificado (.cer) e abra com duplo-clique
7. No Keychain Access, encontre o certificado, clique com botão direito → **Export**
8. Salve como .p12 e defina uma senha

### Converter para base64:
```bash
base64 -i Certificates.p12 | pbcopy
# O conteúdo está na área de transferência — cole no GitHub Secret
```

### Sem Mac (via Codemagic):
O Codemagic pode gerar os certificados automaticamente se você
configurar a API Key do App Store Connect (Passo 3).

---

## Passo 2: Criar Provisioning Profile

1. Acesse [developer.apple.com/account/resources/profiles](https://developer.apple.com/account/resources/profiles/add)
2. Selecione **App Store Connect**
3. Selecione o App ID: `com.greenexpress.orders`
4. Selecione o certificado criado no Passo 1
5. Dê um nome (ex: "GreenExpress AppStore") e baixe

### Converter para base64:
```bash
base64 -i GreenExpress_AppStore.mobileprovision | pbcopy
```

---

## Passo 3: Criar API Key do App Store Connect

1. Acesse [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api)
2. Clique em **Generate API Key**
3. Nome: "GitHub Actions"
4. Permissão: **App Manager**
5. Anote o **Key ID** e o **Issuer ID** (mostrados na página)
6. Baixe a chave privada (.p8) — **só pode baixar uma vez!**

### Configurar no GitHub:
- `APPSTORE_API_KEY_ID` → O Key ID anotado
- `APPSTORE_API_ISSUER_ID` → O Issuer ID mostrado no topo
- `APPSTORE_API_PRIVATE_KEY` → O conteúdo do arquivo .p8

---

## Passo 4: Adicionar Secrets no GitHub

1. Acesse: `github.com/DymytrieV12/Projeto-Gex/settings/secrets/actions`
2. Clique em **New repository secret** para cada um
3. Cole os valores obtidos nos passos anteriores

---

## Passo 5: Atualizar ExportOptions.plist

Edite o arquivo `ios/ExportOptions.plist` e substitua:
- `YOUR_TEAM_ID` → Seu Team ID (encontrado em developer.apple.com/account → Membership)
- `YOUR_PROVISIONING_PROFILE_UUID` → UUID do provisioning profile

---

## 🚀 Pronto!

Após configurar tudo, o workflow roda automaticamente a cada push
na branch `main`, ou manualmente pelo botão "Run workflow" no
GitHub Actions. O .ipa será gerado e disponibilizado como artefato.

Para upload automático no TestFlight, selecione `true` na opção
"Upload para TestFlight?" ao disparar o workflow manualmente.
