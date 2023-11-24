SELECT
    lt_endereco,
    ts_rank(address_tsvector, query) AS rank
FROM
    lotesimplantados li,
    plainto_tsquery(
        'address',
        filter_text('sucupira ch 6 lt 4')
    ) query
WHERE query @@ address_tsvector
ORDER BY rank DESC;

WITH cte AS (
    SELECT
        li.*,
        ras.nome AS lt_ra_nome,
        websearch_to_tsquery(
            'address',
                   filter_text(lt_endereco)        || ' ' ||
                   filter_text(lt_setor)           || ' ' ||
            '"' || filter_text(lt_quadra)   || '"' || ' ' ||
            '"' || filter_text(lt_conjunto) || '"' || ' ' ||
            '"' || filter_text(lt_lote)     || '"'
        ) AS query
    FROM lotesimplantados li
    LEFT JOIN ras ON ras.numero = lt_ra
    WHERE ras.numero = 17
)
SELECT
    *
FROM (
    SELECT
        cte.ct_ciu,
        cte.lt_endereco,
        cte.lt_setor,
        cte.lt_quadra,
        cte.lt_conjunto,
        cte.lt_lote,
        cte.lt_nome,
        cte.lt_ra_nome,
        cf.endereco,
        cf.bairro,
        cf.cidade,
        ts_rank(cf.address_tsvector, cte.query) AS ts_rank,
        rank() OVER(PARTITION BY cte.ct_ciu ORDER BY ts_rank(cf.address_tsvector, cte.query) DESC) AS rank
    FROM cadastrofiscal cf, cte
    WHERE cf.bairro ILIKE '%' || cte.lt_ra_nome || '%' AND cte.query @@ cf.address_tsvector
) t
WHERE rank = 1
ORDER BY ts_rank DESC;
