// --- Serviço de Consultas à API ---
// Este arquivo concentra todos os métodos de consulta à API

/**
 * Consulta informações de uma etiqueta através do webservice
 * @param {string|number} codigoBalanca - Código da balança (6 primeiros dígitos)
 * @param {string|number} codigoEtiqueta - Código da etiqueta (restante dos dígitos)
 * @returns {Promise<Object|null>} Retorna o objeto do produto ou null em caso de erro
 */
async function consultarEtiqueta(codigoBalanca, codigoEtiqueta) {
    try {
        const response = await fetch('https://fluxo.telecon.cloud/webhook/PrevineAI/ConsultarEtiqueta', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                codigoBalanca: codigoBalanca,
                codigoEtiqueta: codigoEtiqueta
            })
        });

        if (!response.ok) {
            throw new Error(`Erro na requisição: ${response.status}`);
        }

        // Verifica se a resposta tem conteúdo antes de fazer parse
        const text = await response.text();
        if (!text || text.trim() === '') {
            console.warn('Resposta vazia do webservice');
            return null;
        }

        const produto = JSON.parse(text);
        return produto;
    } catch (error) {
        console.error('Erro ao consultar webservice:', error);
        if (error.name === 'TypeError' && error.message.includes('Failed to fetch')) {
            console.error('Possível problema de CORS ou URL incorreta');
        }
        return null;
    }
}

/**
 * Consulta informações de pack virtual através do webservice
 * @param {string|number} codigoBalanca - Código da balança (6 primeiros dígitos)
 * @param {string|number} codigoEtiqueta - Código da etiqueta (restante dos dígitos)
 * @returns {Promise<Object|Array|null>} Retorna o objeto/array de pack virtual ou null em caso de erro
 */
async function consultarPackVirtual(codigoBalanca, codigoEtiqueta) {
    try {
        const response = await fetch('https://fluxo.telecon.cloud/webhook/PrevineAI/ConsultarPackVirtual', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                codigoBalanca: codigoBalanca,
                codigoEtiqueta: codigoEtiqueta
            })
        });

        if (!response.ok) {
            throw new Error(`Erro na requisição: ${response.status}`);
        }

        // Verifica se a resposta tem conteúdo antes de fazer parse
        const text = await response.text();
        if (!text || text.trim() === '') {
            console.warn('Resposta vazia do pack virtual');
            return null;
        }

        const packVirtual = JSON.parse(text);
        return packVirtual;
    } catch (error) {
        console.error('Erro ao consultar pack virtual:', error);
        if (error.name === 'TypeError' && error.message.includes('Failed to fetch')) {
            console.error('Possível problema de CORS ou URL incorreta');
        }
        if (error.name === 'SyntaxError') {
            console.error('Resposta não é um JSON válido');
        }
        return null;
    }
}

/**
 * Envia mensagem para o chat IA
 * @param {string} codUser - Identificador do usuário (sessão)
 * @param {string} message - Mensagem do usuário
 * @param {string} initialMessage - Mensagem inicial (contexto) ou null
 * @param {string} productDescription - Nome/Descrição do produto
 * @param {Object} promoDescription - Objeto completo da promoção
 * @returns {Promise<string>} Resposta da IA
 */
async function consultarChatIA(codUser, message, initialMessage, productDescription, promoDescription, ipClient) {
    try {
        const payload = {
            codUser: codUser,
            message: message,
            InitialMessage: initialMessage,
            productDescription: productDescription,
            promoDescription: promoDescription,
            ipClient: ipClient || ""
        };

        const response = await fetch('https://fluxo.telecon.cloud/webhook/PrevineAI/ChatIA', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            throw new Error(`Erro na requisição ChatIA: ${response.status}`);
        }

        const text = await response.text();
        try {
            const json = JSON.parse(text);
            if (json.output) {
                return json.output;
            }
            // Retorna o objeto em si caso não tenha propriedade output, ou o texto original limpo
            if (typeof json === 'string') return json;
            return text;
        } catch (e) {
            // Se não for JSON, retorna o texto puro
            // Remove aspas sobrando se for string JSON-encoded simples
            if (text.startsWith('"') && text.endsWith('"')) {
                return JSON.parse(text);
            }
            return text;
        }
    } catch (error) {
        console.error('Erro ao consultar ChatIA:', error);
        return "Desculpe, estou com dificuldades de conexão no momento. Tente novamente em instantes.";
    }
}

/**
 * Envia dados de acesso e geolocalização para log
 * @param {string} codigoBalanca 
 * @param {string} codigoEtiqueta 
 * @param {number} latitude 
 * @param {number} longitude 
 * @param {number} accuracy 
 * @returns {Promise<boolean>} Retorna true se gravou com sucesso
 */
async function gravarDadosAcesso(codigoBalanca, codigoEtiqueta, latitude, longitude, accuracy, ipClient, codigoSessao) {
    try {
        const payload = {
            body: {
                codigoBalanca: codigoBalanca || "",
                codigoEtiqueta: codigoEtiqueta || "",
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                ipClient: ipClient || "",
                codigoSessao: codigoSessao || ""
            }
        };

        const response = await fetch('https://fluxo.telecon.cloud/webhook/PrevineAI/gravarDadosAcesso', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            console.error(`Erro ao gravar dados de acesso: ${response.status}`);
            return false;
        }
        return true;
    } catch (error) {
        console.error('Erro ao chamar webservice de log de acesso:', error);
        return false;
    }
}
