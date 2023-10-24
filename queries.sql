SELECT
    lt_endereco,
    ts_rank(address_tsvector, query) AS rank
FROM
    lotes_implantados li,
    plainto_tsquery(
        'address',
        filter_text('sucupira ch 6 lt 4')
    ) query
WHERE query @@ address_tsvector
ORDER BY rank DESC;

WITH li AS (
    SELECT
        *,
        websearch_to_tsquery(
            'address',
                   filter_text(lt_setor)           || ' ' ||
            '"' || filter_text(lt_quadra)   || '"' || ' ' ||
            '"' || filter_text(lt_conjunto) || '"' || ' ' ||
                   filter_text(lt_lote)
        ) AS query
    FROM lotes_implantados
    LIMIT 1000
)
SELECT
    *
FROM (
    SELECT
        li.ct_ciu,
        c.endereco,
        c.bairro,
        c.cidade,
        li.lt_endereco,
        ts_rank(c.address_tsvector, li.query) AS ts_rank,
        rank() OVER(PARTITION BY li.ct_ciu ORDER BY ts_rank(c.address_tsvector, li.query) DESC) AS rank
    FROM cadastrofiscal c, li
    WHERE li.query @@ c.address_tsvector
) t
WHERE rank = 1;
