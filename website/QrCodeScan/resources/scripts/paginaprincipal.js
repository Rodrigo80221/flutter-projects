// --- 1. Dados Fictícios (Simulando Banco de Dados) ---
const dbProdutos = {
    '123': {
        nome: 'Produto não Encontrado',
        img: '',
        pesoBruto: '-',
        preco: 'R$ 0,00'
    },
    'default': {
        nome: 'Produto não encontrado',
        pesoBruto: '-',
        preco: 'R$ 0,00'
    }
};

// --- 2. Carregar Dados via URL ---
// Exemplo de URL real:
// https://www.supermago.com.br/01/02453480415907/21/4751550097693?11=...
//
// Regra:
// - Após o segmento "21" vem um número, ex: 4751550097693
// - Os 6 primeiros dígitos = código da balança
// - O restante = código da etiqueta
//
// Obs.: Mantemos também suporte ao parâmetro ?id= para testes locais.

// --- 2. Carregar Dados via URL (Versão Corrigida para GS1) ---

// Tenta pegar do pathname (Azure/Produção) ou do hash (Fallback/Local)
const fullPath = window.location.pathname + window.location.hash;
// Remove query string de possíveis segmentos antes do split
const cleanPath = fullPath.split('?')[0];
const pathnameParts = cleanPath.split('/').filter(Boolean);

console.log("Caminho detectado:", fullPath);
console.log("Pathname parts:", pathnameParts);

// Procura o segmento "21" (Identificador GS1 para Serial/Código)
let codigoEtiquetaCompleto = null;
const idx21 = pathnameParts.indexOf('21');
console.log("Index 21 found at:", idx21);

if (idx21 !== -1 && pathnameParts[idx21 + 1]) {
    // Pega o valor após o /21/ e limpa possíveis query strings (caso não tenha sido limpo antes)
    codigoEtiquetaCompleto = pathnameParts[idx21 + 1].split('?')[0];
    console.log("Extracted code from pathname:", codigoEtiquetaCompleto);
}

// Fallback para teste legado (?code=) ou (?id=)
const params = new URLSearchParams(window.location.search);
if (!codigoEtiquetaCompleto) {
    codigoEtiquetaCompleto = params.get('code') || params.get('id');
}

console.log("Código Final Identificado:", codigoEtiquetaCompleto);


// Mantém fallback para teste com query string (?id=123)


// Se encontrou o código completo, separa balança/etiqueta
let codigoBalanca = null;
let codigoEtiqueta = null;
if (codigoEtiquetaCompleto && codigoEtiquetaCompleto.length > 6) {
    codigoBalanca = codigoEtiquetaCompleto.slice(0, 6);
    codigoEtiqueta = codigoEtiquetaCompleto.slice(6);
}


// Aqui você decide qual ID usar para o "banco fictício":
// - Preferimos o codigoEtiqueta (quando existe),
// - depois o id da query (?id=),
// - por fim um valor padrão "123".
const id = codigoEtiqueta || codigoEtiquetaCompleto || '123';

// --- Helpers ---
const mensagemPadraoChat = 'Olá! Sou o Maguinho.';
let pesoBrutoNumero = null;
let qtdRegraAtual = null;

function parsePesoKg(valor) {
    if (valor === null || valor === undefined) return null;
    if (typeof valor === 'number') return valor;
    const cleaned = String(valor)
        .replace(/,/g, '.')      // vírgula para ponto
        .replace(/[^0-9.]/g, ''); // remove letras
    const num = parseFloat(cleaned);
    return isNaN(num) ? null : num;
}

function formatKg(valor) {
    if (valor === null || valor === undefined || isNaN(valor)) return '-';
    return `${valor.toFixed(3).replace('.', ',')} kg`;
}

function atualizarObservacaoPromo() {
    const obsDiv = document.getElementById('promoObsText');
    if (pesoBrutoNumero === null || qtdRegraAtual === null) {
        obsDiv.style.display = 'none';
        return;
    }
    if (pesoBrutoNumero < qtdRegraAtual) {
        const pesoAtualFmt = formatKg(pesoBrutoNumero);
        const qtdRegraFmt = formatKg(qtdRegraAtual);
        const msg = `<span style="color: var(--mago-red); font-weight: 800;">Falta pouco!</span> O peso atual é <b style="color: var(--mago-red)">${pesoAtualFmt}</b>. Adicione mais itens até atingir <b style="color: var(--mago-red)">${qtdRegraFmt}</b> para garantir a promoção.`;
        obsDiv.innerHTML = msg;
        obsDiv.style.display = 'block';
    } else {
        obsDiv.style.display = 'none';
    }
}

// --- Função para preencher a página com dados do produto ---
function preencherPagina(produto, codigoExibido) {
    document.getElementById('nomeProduto').innerText = produto.nome;
    // Adiciona "Kg" após o peso bruto se não já tiver
    const pesoBrutoValue = String(produto.pesoBruto || '-');
    const pesoBrutoComKg = pesoBrutoValue.toLowerCase().includes('kg') ? pesoBrutoValue : pesoBrutoValue + ' Kg';
    document.getElementById('pesoBruto').innerText = pesoBrutoComKg;
    pesoBrutoNumero = parsePesoKg(produto.pesoBruto);

    // --- Lógica de Preço Total ---
    // Garante prefixo "R$" no preço total original
    let precoValue = String(produto.preco || '--').trim();
    // Remove R$ para processamento se necessário, mas aqui queremos apenas garantir que existe para display
    if (!precoValue.startsWith('R$') && precoValue !== '--') {
        precoValue = `R$ ${precoValue}`;
    }

    const precoEl = document.getElementById('preco');
    const possuiPromocao = String(produto.PossuiPromocao).toLowerCase() === 'true';

    if (possuiPromocao && produto.ValorVendaPromo) {
        // Oculta o label "Preço Total:" durante a promoção
        if (labelPrecoTotal) labelPrecoTotal.style.display = 'none';

        // Formata o preço promocional
        const valorPromoFmt = parseFloat(produto.ValorVendaPromo).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

        // Monta o HTML: De R$ XX por R$ YY
        // "De R$ XX": cinza e riscado, fonte menor
        // "por": cinza escuro/preto (não vermelho)
        // "R$ YY": vermelho destaque, fonte maior/negrito
        precoEl.innerHTML = `
            <span style="color: #495057; font-weight: 600; font-size: 0.6em; margin-right: 0px;">De </span>
            <span style="text-decoration: line-through; color: #6c757d; font-size: 0.6em; margin-right: 0px;">${precoValue}</span>
            <span style="color: #495057; font-weight: 600; font-size: 0.6em; margin-right: 0px;">por</span>
            <span style="color: #28a745; font-weight: 800;">R$ ${valorPromoFmt}</span>
        `;
    } else {
        // Restaura o label
        if (labelPrecoTotal) labelPrecoTotal.style.display = 'inline';
        precoEl.innerText = precoValue;
    }

    document.getElementById('imgProduto').src = produto.img || FALLBACK_IMG;

    // Atualiza link do logo se houver site
    const linkLogo = document.getElementById('linkLogo');
    if (produto.site) {
        linkLogo.href = produto.site;
        linkLogo.style.pointerEvents = 'auto';
    } else {
        linkLogo.href = '#';
        linkLogo.style.pointerEvents = 'none';
    }

    // Configura link do produto principal (UrlEcommerce ou site)
    const linkProdutoPrincipal = document.getElementById('linkProdutoPrincipal');
    if (linkProdutoPrincipal) {
        const urlDestino = produto.UrlEcommerce || produto.site;
        if (urlDestino) {
            linkProdutoPrincipal.href = urlDestino;
            linkProdutoPrincipal.style.pointerEvents = 'auto';
            linkProdutoPrincipal.style.cursor = 'pointer';
        } else {
            linkProdutoPrincipal.href = '#';
            linkProdutoPrincipal.style.pointerEvents = 'none';
            linkProdutoPrincipal.style.cursor = 'default';
        }
    }

    // Exibe Valor de Venda Unitário se disponível
    const valorVendaContainer = document.getElementById('valorVendaContainer');
    const labelUnidade = document.getElementById('labelUnidade');
    const valorVendaEl = document.getElementById('valorVenda');

    // Decide qual valor unitário usar (Normal ou Promoção)
    let valorUnitario = produto.ValorVenda;
    if (possuiPromocao && produto.ValorPromocao) {
        valorUnitario = produto.ValorPromocao;
    }

    if (valorUnitario && produto.Unidade) {
        // Formata o valor numérico (ex: 34.99 -> 34,99)
        const valorFmt = parseFloat(valorUnitario).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        // Define o label (ex: R$/ Kg:)
        labelUnidade.innerText = `R$/ ${produto.Unidade}:`;
        // Define o valor
        valorVendaEl.innerText = valorFmt;
        // Exibe o container
        valorVendaContainer.style.display = 'inline';
    } else {
        valorVendaContainer.style.display = 'none';
    }

    atualizarObservacaoPromo();
}

// --- Função para definir a mensagem inicial do chat ---
function definirMensagemInicialChat(textoVenda) {
    const chatBody = document.getElementById('chatBody');
    let raw = (textoVenda && textoVenda !== 'null') ? textoVenda : mensagemPadraoChat;
    raw += '\n\nQuer uma receita mágica? **É só me perguntar!** ✨ 👇';

    // Escapa HTML básico, converte **texto** em <b>texto</b> e preserva quebras de linha
    const escapeHtml = (str) => String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');

    const html = escapeHtml(raw)
        .replace(/\*\*(.+?)\*\*/g, '<b>$1</b>')
        .replace(/\r?\n/g, '<br>');

    chatBody.innerHTML = `<div class="msg msg-bot clearfix">${html}</div>`;
    chatBody.scrollTop = chatBody.scrollHeight;
}

// --- Função para preencher a seção de promoção com dados do pack virtual ---
function preencherPromocao(packVirtual) {
    const promoSection = document.getElementById('promoSection');
    const promoTexto = document.getElementById('promoTexto');
    const produtosContainer = document.getElementById('promoProdutos');
    const obsDiv = document.getElementById('promoObsText');
    const promoHeader = promoSection.querySelector('.promo-header');

    if (!packVirtual) {
        exibirEstadoVazioPromo(promoSection, promoTexto, produtosContainer, obsDiv, promoHeader);
        return;
    }

    // O endpoint pode retornar um objeto único ou um array
    // Se for array, pega o primeiro item; se for objeto, usa diretamente
    const pack = Array.isArray(packVirtual) ? packVirtual[0] : packVirtual;

    if (!pack || !pack.DescricaoPack) {
        exibirEstadoVazioPromo(promoSection, promoTexto, produtosContainer, obsDiv, promoHeader);
        return;
    }

    // Reset header text when promo exists
    if (promoHeader) promoHeader.innerText = 'PROMOÇÃO SURPRESA!';

    // Guarda qtd da regra para comparação
    qtdRegraAtual = parsePesoKg(pack.QtdRegra);

    // Preenche a descrição do pack
    promoTexto.innerText = pack.DescricaoPack;

    // Limpa e preenche a lista de produtos
    produtosContainer.innerHTML = '';

    if (pack.Produtos && Array.isArray(pack.Produtos) && pack.Produtos.length > 0) {
        pack.Produtos.forEach(produto => {
            // Se tiver UrlEcommerce cria um <a>, senão cria <div>
            // Fallback: se não tem UrlEcommerce no produto da promo, usa o site do produto principal
            const targetUrl = produto.UrlEcommerce || (produtoAtual ? produtoAtual.site : null);

            const tag = targetUrl ? 'a' : 'div';
            const produtoDiv = document.createElement(tag);

            produtoDiv.className = 'promo-produto-item mb-2 text-decoration-none'; // Adiciona text-decoration-none para remover sublinhado

            if (targetUrl) {
                produtoDiv.href = targetUrl;
                produtoDiv.target = '_blank';
                // Garante que o item ocupe o espaço e mantenha o layout flex
                produtoDiv.style.display = 'flex';
                produtoDiv.style.color = 'inherit'; // Mantém cores originais
                produtoDiv.style.cursor = 'pointer';
            }

            // Corrige URLs com &amp; para &
            const urlImagem = (produto.URL || '').replace(/&amp;/g, '&');
            produtoDiv.innerHTML = `
                    <img src="${urlImagem || 'https://via.placeholder.com/80'}" 
                         alt="${produto.DESCRICAO || 'Produto'}" 
                         class="promo-produto-img me-2"
                         onerror="this.src='https://via.placeholder.com/80'">
                    <span class="promo-produto-desc">${produto.DESCRICAO || 'Produto'}</span>
                `;
            produtosContainer.appendChild(produtoDiv);
        });
    }

    // Exibe a seção de promoção e atualiza observação
    promoSection.style.display = 'block';
    atualizarObservacaoPromo();
}

function exibirEstadoVazioPromo(section, textDiv, productsDiv, obsDiv, headerDiv) {
    section.style.display = 'block';
    if (headerDiv) headerDiv.innerText = '🎩 Magia em Andamento!';
    textDiv.innerHTML = 'Ops! Nenhuma promoção mágica por aqui… ainda!<br>O Maguinho está preparando novas ofertas para você ✨🔥';
    productsDiv.innerHTML = '';
    obsDiv.style.display = 'none';
    qtdRegraAtual = null;
}

function exibirEstadoMagico() {
    // Esconde imagem e detalhes de preço/peso
    document.querySelector('.product-img-wrap').style.display = 'none';
    document.querySelector('.detail-row').style.display = 'none';
    document.querySelector('.price-inline').style.display = 'none';

    // Exibe mensagem mágica
    const msg = "Essa embalagem sumiu do nosso estoque mágico! 🧙‍♂️\nTente outro produto ou fale com o Maguinho para receber dicas mágicas.";
    // Converte quebras de linha para HTML
    const nomeProduto = document.getElementById('nomeProduto');
    nomeProduto.innerHTML = msg.replace(/\n/g, '<br>');
    nomeProduto.classList.add('magic-text'); // Adiciona classe para estilização
}

// --- Carregar dados do produto ---
// Se temos codigoBalanca e codigoEtiqueta, consulta o webservice
// Caso contrário, usa o banco fictício como fallback
let produtoAtual; // Variável global para ser usada no chat
let promoAtual = null; // Variável global para promo
let codigoExibido = id;

// setar variaveis manualmente
//codigoBalanca = 475155;
//codigoEtiqueta = 97897;

const FALLBACK_IMG = 'https://t0.gstatic.com/images?q=tbn:ANd9GcTrTKArD5zhH6N8hUZbrDvpmL0kvN2sySDiTaT9AS8c2RaQg-I8KQ3H2pgVuKU&s';

if (codigoBalanca && codigoEtiqueta) {
    // Consulta o webservice da etiqueta
    consultarEtiqueta(codigoBalanca, codigoEtiqueta)
        .then(produtoWS => {
            if (produtoWS) {
                // Se for array, pega o primeiro item
                produtoAtual = Array.isArray(produtoWS) ? produtoWS[0] : produtoWS;
                codigoExibido = codigoEtiqueta;
                preencherPagina(produtoAtual, codigoExibido);
                definirMensagemInicialChat(produtoAtual?.textovenda);

                // Consulta o pack virtual para a promoção
                return consultarPackVirtual(codigoBalanca, codigoEtiqueta);
            } else {
                // Se não encontrou produto no WS, exibe estado mágico
                exibirEstadoMagico();
                definirMensagemInicialChat(null);
                // Retorna null para pular o próximo then de pack sem erro
                return null;
            }
        })
        .then(packVirtual => {
            if (packVirtual) {
                promoAtual = packVirtual;
                preencherPromocao(packVirtual);
            } else {
                const promoSection = document.getElementById('promoSection');
                const promoTexto = document.getElementById('promoTexto');
                const produtosContainer = document.getElementById('promoProdutos');
                const obsDiv = document.getElementById('promoObsText');
                const promoHeader = promoSection.querySelector('.promo-header');
                exibirEstadoVazioPromo(promoSection, promoTexto, produtosContainer, obsDiv, promoHeader);
            }
        })
        .catch(err => {
            console.error('Erro ao processar resposta:', err);
            // Em caso de erro (ex: 404, rede), exibe estado mágico
            exibirEstadoMagico();
            definirMensagemInicialChat(null);

            const promoSection = document.getElementById('promoSection');
            const promoTexto = document.getElementById('promoTexto');
            const produtosContainer = document.getElementById('promoProdutos');
            const obsDiv = document.getElementById('promoObsText');
            const promoHeader = promoSection.querySelector('.promo-header');
            exibirEstadoVazioPromo(promoSection, promoTexto, produtosContainer, obsDiv, promoHeader);
        });
} else {
    // Caso SEM códigos na URL: Exibe estado mágico
    exibirEstadoMagico();
    definirMensagemInicialChat(null);

    const promoSection = document.getElementById('promoSection');
    const promoTexto = document.getElementById('promoTexto');
    const produtosContainer = document.getElementById('promoProdutos');
    const obsDiv = document.getElementById('promoObsText');
    const promoHeader = promoSection.querySelector('.promo-header');
    exibirEstadoVazioPromo(promoSection, promoTexto, produtosContainer, obsDiv, promoHeader);
}

// --- 3. Lógica do Chat (Parcial - Inicialização de Sessão) ---
// Gera um ID de usuário único armazenado em memória (ou localStorage se preferir persistência)
function gerarIdUsuario() {
    return 'user-' + Math.random().toString(36).substr(2, 9) + '-' + Date.now();
}

// Gera um novo ID sempre que a página carrega (sessão nova)
const codUser = gerarIdUsuario();
// Atualiza o storage apenas para manter registro atual, se necessário
localStorage.setItem('chat_codUser', codUser);

// --- 4. Log de Acesso com Geolocalização ---
let acessoRegistrado = false;
let globalIpClient = null;

async function registrarAcesso(isRetry = false) {
    // Se já registrou com sucesso, não tenta novamente
    if (acessoRegistrado) return;

    // Obtém o IP do cliente
    try {
        const responseHelper = await fetch('https://api.ipify.org?format=json');
        const dataHelper = await responseHelper.json();
        globalIpClient = dataHelper.ip;
    } catch (e) {
        console.warn("Não foi possível obter o IP do cliente:", e);
    }

    if ("geolocation" in navigator) {
        navigator.geolocation.getCurrentPosition(
            async (position) => {
                const lat = position.coords.latitude;
                const lon = position.coords.longitude;
                const acc = position.coords.accuracy;

                // Chama a API de log com IP (Sempre grava se tiver sucesso na GEO, mesmo sendo retry)
                const sucesso = await gravarDadosAcesso(codigoBalanca, codigoEtiqueta, lat, lon, acc, globalIpClient, codUser);
                if (sucesso) acessoRegistrado = true;
            },
            async (error) => {
                // Se for retentativa e falhou novamente a GEO, NÃO grava dado fallback para evitar duplicidade
                if (isRetry) {
                    console.warn("Retentativa de geolocalização falhou. Evitando duplicidade de log sem coordenadas.");
                    return;
                }

                if (error.code === error.PERMISSION_DENIED) {
                    console.warn("Usuário negou a permissão de geolocalização. Gravando apenas dados do produto e IP.");
                } else {
                    console.warn("Erro ao obter geolocalização:", error.message);
                }
                // Registra acesso sem coordenadas (fallback) mas com IP
                const sucesso = await gravarDadosAcesso(codigoBalanca, codigoEtiqueta, null, null, null, globalIpClient, codUser);
                if (sucesso) acessoRegistrado = true;
            },
            {
                enableHighAccuracy: true,
                timeout: 30000,
                maximumAge: 0
            }
        );
    } else {
        console.warn("Geolocalização não suportada pelo navegador.");

        // Se for retentativa, evita duplicidade
        if (isRetry) return;

        // Registrar acesso mesmo sem geolocalização se não suportado, enviando IP
        const sucesso = await gravarDadosAcesso(codigoBalanca, codigoEtiqueta, null, null, null, globalIpClient, codUser);
        if (sucesso) acessoRegistrado = true;
    }
}

// Inicia o registro de acesso imediatamente
registrarAcesso(false);

// Tenta novamente após 10 segundos caso não tenha conseguido ainda
setTimeout(() => {
    if (!acessoRegistrado) {
        console.log("Tentando registrar acesso novamente (retry 10s)...");
        registrarAcesso(true);
    }
}, 10000);

// --- 3. Lógica do Chat ---


let isFirstMessage = true;

function enviarMsg() {
    const input = document.getElementById('inputMsg');
    const chatBody = document.getElementById('chatBody');
    const btnEnviar = document.querySelector('button[onclick="enviarMsg()"]');
    const txt = input.value.trim();

    if (!txt) return;

    // Reinicia e toca o vídeo de fundo ao enviar mensagem
    const video = document.querySelector('.chat-bg-video');
    if (video) {
        video.currentTime = 0;
        video.play();
    }

    // Renderiza User
    chatBody.innerHTML += `<div class="msg msg-user clearfix">${txt}</div>`;
    input.value = '';
    input.disabled = true;
    if (btnEnviar) btnEnviar.disabled = true;
    chatBody.scrollTop = chatBody.scrollHeight;

    // Prepara payload
    let initialMsg = null;
    if (isFirstMessage) {
        initialMsg = (produtoAtual?.textovenda || 'Receitas e Dicas Gerais');
        initialMsg += '\n\nQuer uma receita mágica? **É só me perguntar!** ✨ 👇';
    }

    // Exibe "Digitando..."
    const loadingId = 'loading-' + Date.now();
    chatBody.innerHTML += `<div id="${loadingId}" class="msg msg-bot msg-bot-space clearfix">
        <i class="fas fa-spinner fa-spin "></i> O Maguinho está escrevendo...
    </div>`;
    chatBody.scrollTop = chatBody.scrollHeight;

    // Dados adicionais
    const productDescription = produtoAtual ? produtoAtual.nome : null;
    const promoDescription = promoAtual ? promoAtual : null;

    // Chama API
    consultarChatIA(codUser, txt, initialMsg, productDescription, promoDescription, globalIpClient)
        .then(responseHtml => {
            // Remove loading
            const loadingDiv = document.getElementById(loadingId);
            if (loadingDiv) loadingDiv.remove();

            // Renderiza resposta da IA
            // Se vier texto puro com quebras, converte. Se vier HTML, injeta.
            let finalHtml = responseHtml;
            if (!finalHtml.includes('<')) {
                // assume texto simples
                finalHtml = finalHtml
                    .replace(/\*\*(.+?)\*\*/g, '<b>$1</b>') // Bold marker (Double)
                    .replace(/\*(.+?)\*/g, '<b>$1</b>') // Bold marker (Single)
                    .replace(/\r?\n/g, '<br>');
            }

            chatBody.innerHTML += `<div class="msg msg-bot msg-bot-space clearfix">${finalHtml}</div>`;
            chatBody.scrollTop = chatBody.scrollHeight;

            // Atualiza estado de primeira mensagem
            if (isFirstMessage) isFirstMessage = false;
        })
        .catch(err => {
            console.error(err);
            const loadingDiv = document.getElementById(loadingId);
            if (loadingDiv) loadingDiv.remove();
            chatBody.innerHTML += `<div class="msg msg-bot msg-bot-space clearfix text-danger">Erro ao conectar com o Maguinho.</div>`;
        })
        .finally(() => {
            input.disabled = false;
            if (btnEnviar) btnEnviar.disabled = false;
            input.focus();
        });
}


// Enviar com Enter
document.getElementById('inputMsg').addEventListener("keypress", function (event) {
    if (event.key === "Enter") enviarMsg();
});

// Focar no input ao clicar em qualquer lugar do chat
document.querySelector('.chat-container').addEventListener('click', function () {
    document.getElementById('inputMsg').focus();
});

