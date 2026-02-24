const API_URL = 'https://fluxo.telecon.cloud/webhook/PrevineAI/HistoricoDadosAcesso';

/**
 * Consulta o histórico de dados de acesso na API.
 * @param {string} dataInicial - Data inicial no formato YYYY-MM-DD.
 * @param {string} dataFinal - Data final no formato YYYY-MM-DD.
 * @param {boolean} apenasComInteracao - Filtrar apenas registros com interação.
 * @returns {Promise<Array>} - Promessa que retorna uma lista de registros.
 */
async function consultarDadosAcesso(dataInicial, dataFinal, apenasComInteracao = false) {
    const url = new URL(API_URL);
    url.searchParams.append('dataInicial', dataInicial);
    url.searchParams.append('dataFinal', dataFinal);
    url.searchParams.append('apenasComInteracao', apenasComInteracao);

    const response = await fetch(url);

    if (!response.ok) {
        throw new Error(`Erro na requisição: ${response.status}`);
    }

    let rawData = await response.json();
    console.log('API Response:', rawData); // Debug for user

    let dataToRender = [];

    if (Array.isArray(rawData)) {
        dataToRender = rawData;
    } else if (rawData && typeof rawData === 'object') {
        // 1. Check for standard wrapper keys
        if (Array.isArray(rawData.value)) {
            dataToRender = rawData.value;
        } else if (Array.isArray(rawData.results)) {
            dataToRender = rawData.results;
        } else if (Array.isArray(rawData.data)) {
            dataToRender = rawData.data;
        } else if (Array.isArray(rawData.d)) {
            dataToRender = rawData.d;
        } else {
            // 2. Fallback: Search for ANY property that is an array
            const arrayProp = Object.values(rawData).find(val => Array.isArray(val));
            if (arrayProp) {
                dataToRender = arrayProp;
            } else {
                // 3. Assume the object itself is a single record
                dataToRender = [rawData];
            }
        }
    }

    // Filter out empty or invalid objects (e.g. { "results": [{}] })
    return dataToRender.filter(item => item && (item.Id || item.DataHoraAcesso || item.Descricao));
}
