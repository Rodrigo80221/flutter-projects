

document.addEventListener('DOMContentLoaded', () => {
    const btnConsultar = document.getElementById('btnConsultar');
    const dataInicialInput = document.getElementById('dataInicial');
    const dataFinalInput = document.getElementById('dataFinal');
    const apenasComInteracaoInput = document.getElementById('apenasComInteracao');
    const resultsArea = document.getElementById('results-area');
    const statusMessage = document.getElementById('status-message');
    const tableBody = document.getElementById('tabela-corpo');
    const mobileCardsContainer = document.getElementById('mobile-cards');

    // Set default dates to Today
    const now = new Date();
    const today = new Date(now.getTime() - (now.getTimezoneOffset() * 60000)).toISOString().split('T')[0];

    dataInicialInput.value = today;
    dataFinalInput.value = today;

    btnConsultar.addEventListener('click', async () => {
        const dataInicial = dataInicialInput.value;
        const dataFinal = dataFinalInput.value;
        const apenasComInteracao = apenasComInteracaoInput.checked;

        if (!dataInicial || !dataFinal) {
            alert('Por favor, selecione ambas as datas: Inicial e Final.');
            return;
        }

        if (dataInicial > dataFinal) {
            alert('A Data Inicial não pode ser maior que a Data Final.');
            return;
        }

        // Set Loading State
        setLoading(true);
        clearResults();

        try {

            const dataToRender = await consultarDadosAcesso(dataInicial, dataFinal, apenasComInteracao);

            if (dataToRender.length > 0) {
                renderResults(dataToRender);
            } else {
                showStatus('Nenhum registro encontrado para o período selecionado.');
            }

        } catch (error) {
            console.error('Erro:', error);
            showStatus('Ocorreu um erro ao buscar os dados. Tente novamente mais tarde.');
        } finally {
            setLoading(false);
        }
    });

    function setLoading(isLoading) {
        if (isLoading) {
            btnConsultar.classList.add('loading');
            btnConsultar.disabled = true;
            statusMessage.classList.add('hidden');
            resultsArea.classList.add('hidden');
        } else {
            btnConsultar.classList.remove('loading');
            btnConsultar.disabled = false;
        }
    }

    function clearResults() {
        tableBody.innerHTML = '';
        mobileCardsContainer.innerHTML = '';
    }

    function showStatus(message) {
        statusMessage.classList.remove('hidden');
        statusMessage.querySelector('p').textContent = message;
        resultsArea.classList.add('hidden');
    }

    function renderResults(data) {
        resultsArea.classList.remove('hidden');
        statusMessage.classList.add('hidden');

        // Clean previous results
        tableBody.innerHTML = '';
        mobileCardsContainer.innerHTML = '';

        // Calculate Totals
        const totalAcessos = data.length;
        const totalChat = data.filter(item => item.InteracoesChatBot && item.InteracoesChatBot !== 'null' && item.InteracoesChatBot.trim() !== '').length;
        const engagementRate = totalAcessos > 0 ? Math.round((totalChat / totalAcessos) * 100) : 0;

        // Update Summary UI
        document.getElementById('total-acessos').textContent = totalAcessos;
        document.getElementById('total-chat').textContent = totalChat;
        document.getElementById('taxa-engajamento').textContent = `${engagementRate}%`;

        // Show summary card
        const summaryCard = document.getElementById('summary-card');
        if (summaryCard) summaryCard.classList.remove('hidden');

        data.forEach((item, index) => {
            // --- 1. Desktop Table Rendering ---

            // Main Row
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><button class="btn-expand" data-index="${index}" title="Expandir Detalhes">+</button></td>
                <td>
                    <div class="product-cell">
                        ${getProductImage(item.UrlProduto)}
                        <div class="product-info">
                            <span class="product-desc" title="${safeText(item.Descricao)}">${item.Descricao || 'Produto Sem Descrição'}</span>
                            <span class="product-code">Ref: ${item.Barras || '-'}</span>
                        </div>
                    </div>
                </td>
                <td class="date-cell">${formatDate(item.DataHoraAcesso)}</td>
                <td>
                    <div class="location-info">${safeText(item.Cidade)} - ${safeText(item.Estado)}</div>
                    <span class="location-sub">${safeText(item.Rua)}, ${safeText(item.Bairro)}</span>
                </td>
                <td><div class="interaction-text" title="${escapeHtml(item.InteracoesChatBot)}">${formatInteractions(item.InteracoesChatBot)}</div></td>
            `;
            tableBody.appendChild(tr);

            // Details Row (Hidden by default)
            const trDetails = document.createElement('tr');
            trDetails.classList.add('details-row', 'hidden');
            trDetails.id = `details-${index}`;

            // Build details content
            trDetails.innerHTML = `
                <td colspan="5">
                    <div class="details-content">
                        <div class="detail-item"><strong>ID</strong> <span>${safeText(item.Id)}</span></div>
                        <div class="detail-item"><strong>Código Balança</strong> <span>${safeText(item.CodigoBalanca)}</span></div>
                        <div class="detail-item"><strong>Código Etiqueta</strong> <span>${safeText(item.CodigoEtiqueta)}</span></div>
                        <div class="detail-item"><strong>IP do Usuário</strong> <span>${safeText(item.IP_Usuario)}</span></div>
                        
                        <div class="detail-item"><strong>Latitude</strong> <span>${safeText(item.Latitude)}</span></div>
                        <div class="detail-item"><strong>Longitude</strong> <span>${safeText(item.Longitude)}</span></div>
                        <div class="detail-item"><strong>Precisão (m)</strong> <span>${safeText(item.Precisao)}</span></div>
                        <div class="detail-item"><strong>CEP</strong> <span>${safeText(item.CEP)}</span></div>
                        
                        <div class="detail-item full-width"><strong>Endereço Completo</strong> <span>${safeText(item.Rua)}, ${safeText(item.Bairro)}, ${safeText(item.Cidade)} - ${safeText(item.Estado)}, ${safeText(item.Pais)}</span></div>
                        
                        <div class="detail-item full-width"><strong>Código Sessão Completo</strong> <span>${safeText(item.CodigoSessao)}</span></div>

                        <div class="detail-item full-width interactions-box">
                            <strong>Interações Completas (ChatBot)</strong>
                            <div class="interactions-full">${item.InteracoesChatBot || 'Nenhuma interação registrada.'}</div>
                        </div>
                    </div>
                </td>
            `;
            tableBody.appendChild(trDetails);

            // Event Listener for Expand Button
            const btnExpand = tr.querySelector('.btn-expand');
            btnExpand.addEventListener('click', () => {
                const isHidden = trDetails.classList.contains('hidden');

                if (isHidden) {
                    trDetails.classList.remove('hidden');
                    btnExpand.classList.add('expanded');
                    btnExpand.textContent = '×'; // Provide a clear close icon (or CSS rotation handles it)
                } else {
                    trDetails.classList.add('hidden');
                    btnExpand.classList.remove('expanded');
                    btnExpand.textContent = '+';
                }
            });

            // --- 2. Mobile Card Rendering ---
            const card = document.createElement('div');
            card.classList.add('card');
            card.innerHTML = `
                <div class="card-header">
                    <span class="card-date">${formatDate(item.DataHoraAcesso)}</span>
                    <span class="card-ip">${safeText(item.IP_Usuario)}</span>
                </div>
                <div class="card-body">
                    <!-- Product Info for Mobile -->
                    <div class="product-cell mobile-view">
                        ${getProductImage(item.UrlProduto)}
                        <div class="product-info">
                            <span class="product-desc">${item.Descricao || 'Produto Sem Descrição'}</span>
                            <span class="product-code">Ref: ${item.Barras || '-'}</span>
                        </div>
                    </div>
                    
                    <div class="mobile-divider"></div>

                    <p><strong>Local:</strong> ${safeText(item.Cidade)} - ${safeText(item.Estado)}</p>
                    <p><strong>Interações:</strong> ${item.InteracoesChatBot ? truncate(item.InteracoesChatBot, 60) : '-'}</p>
                    <details>
                        <summary style="cursor:pointer; color:var(--primary); margin-top:0.5rem;">Ver Detalhes Completos</summary>
                        <div style="margin-top: 1rem; padding-top: 0.5rem; border-top: 1px solid rgba(255,255,255,0.1);">
                            <p><strong>Rua:</strong> ${safeText(item.Rua)}</p>
                            <p><strong>Bairro:</strong> ${safeText(item.Bairro)}</p>
                            <p><strong>Lat/Long:</strong> ${safeText(item.Latitude)} / ${safeText(item.Longitude)}</p>
                            <div class="interactions-mobile">
                                <strong>Interações:</strong>
                                <div style="white-space: pre-wrap; margin-top: 4px; color: var(--text-muted);">${item.InteracoesChatBot || '-'}</div>
                            </div>
                        </div>
                    </details>
                </div>
            `;
            mobileCardsContainer.appendChild(card);
        });
    }

    function safeText(text) {
        if (!text || text === 'undefined' || text === 'null') return '-';
        return text;
    }

    function getProductImage(url) {
        if (!url || url === 'undefined' || url === 'null') {
            return '<div class="product-thumb-placeholder">📷</div>';
        }
        return `<img src="${url}" alt="Produto" class="product-thumb" onerror="this.onerror=null;this.parentNode.innerHTML='<div class=\\'product-thumb-placeholder\\'>📷</div>'">`;
    }

    function formatDate(dateString) {
        if (!dateString) return '-';
        const date = new Date(dateString);
        if (isNaN(date.getTime())) return '-'; // Check for Invalid Date
        try {
            return new Intl.DateTimeFormat('pt-BR', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                timeZone: 'UTC'
            }).format(date);
        } catch (e) {
            console.error('Error formatting date:', dateString, e);
            return '-';
        }
    }

    function formatInteractions(text) {
        if (!text) return '-';
        // Replace newlines with spaces for compact view or keep them
        return escapeHtml(text).replace(/\r\n/g, '<br />').replace(/\n/g, '<br />');
    }

    function truncate(str, n) {
        return (str && str.length > n) ? str.substr(0, n - 1) + '...' : str;
    }

    function escapeHtml(unsafe) {
        if (!unsafe) return '';
        return unsafe
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }
});
