function valconcat(vals, tagName) {
  if (vals.length === 0) return '';
  var open = '<' + tagName + '>', close = '</' + tagName + '>';
  return open + vals.join(close + open) + close;
}

const dbFileElm = document.getElementById('dbfile');
const outputTableHeadElem = document.getElementById('outputTableHead');
const outputTableBodyElem = document.getElementById('outputTableBody');
const outputNoticeElem = document.getElementById('outputNotice');
const executeButton = document.getElementById('execute');
const SQL = await initSqlJs({
  locateFile: (filename) => {
    return `../../dist/${filename}`;
  }
});
const queries = {
  "Query 6": "SELECT sum(l_extendedprice * l_discount) as revenue FROM lineitem WHERE l_shipdate >= DATE('1994-01-01') AND l_shipdate < DATE('1994-01-01', '+1 years') AND l_discount between 0.06 - 0.01 AND 0.06 + 0.01 AND l_quantity < 24;",
  "Query 1": "select l_returnflag, l_linestatus, sum(l_quantity) as sum_qty, sum(l_extendedprice) as sum_base_price, sum(l_extendedprice *(1 - l_discount)) as sum_disc_price, sum(l_extendedprice *(1 - l_discount) * (1 + l_tax)) as sum_charge, avg(l_quantity) as avg_qty, avg(l_extendedprice) as avg_price, avg(l_discount) as avg_disc, count(*) as count_order from lineitem where l_shipdate <= date('1998-12-01', '+90 day') group by l_returnflag, l_linestatus order by l_returnflag, l_linestatus;",
  "Query 3": "select l_orderkey, sum(l_extendedprice *(1 - l_discount)) as revenue, o_orderdate, o_shippriority from customer, orders, lineitem where c_mktsegment = 'BUILDING' and c_custkey = o_custkey and l_orderkey = o_orderkey and o_orderdate < date('1995-03-15') and l_shipdate > date('1995-03-15') group by l_orderkey, o_orderdate, o_shippriority order by revenue desc, o_orderdate;",
  "Query 9": `select nation, o_year, sum(amount) as sum_profit from ( select n_name as nation, cast(strftime("%Y", date(l_shipdate)) as integer) as o_year, l_extendedprice * (1 - l_discount) - ps_supplycost * l_quantity as amount from part, supplier, lineitem, partsupp, orders, nation where s_suppkey = l_suppkey and ps_suppkey = l_suppkey and ps_partkey = l_partkey and p_partkey = l_partkey and o_orderkey = l_orderkey and s_nationkey = n_nationkey and p_name like '%green%' ) as profit group by nation, o_year order by nation, o_year desc;`,
  "Query 18": "select c_name, c_custkey, o_orderkey, o_orderdate, o_totalprice, sum(l_quantity) from customer, orders, lineitem where o_orderkey in ( select l_orderkey from lineitem group by l_orderkey having sum(l_quantity) > 300 ) and c_custkey = o_custkey and o_orderkey = l_orderkey group by c_name, c_custkey, o_orderkey, o_orderdate, o_totalprice order by o_totalprice desc, o_orderdate;",
}

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function measureQuery(dbFile, queryName, useJIT) {
  const db = new SQL.Database(dbFile);
  const stmt = db.prepare(queries[queryName]);

  if (useJIT) stmt.jit();

  const startTime = new Date();
  while (stmt.step()) { };
  const endTime = new Date();

  return endTime - startTime;
}

executeButton.onclick = () => {
  const f = dbFileElm.files[0];
  const r = new FileReader();
  r.readAsArrayBuffer(f);

  r.onload = async function () {
    outputNoticeElem.innerHTML = "running...";
    outputTableBodyElem.innerHTML = "";
    await sleep(1);

    outputTableHeadElem.innerHTML = valconcat(["Query", "Reference Time", "JIT Time"], 'th');
    const dbFile = new Uint8Array(r.result);

    for (const query in queries) {
      const referenceTime = measureQuery(dbFile, query, false) + "ms";
      const jitTime = measureQuery(dbFile, query, true) + "ms";
      outputTableBodyElem.innerHTML += `<tr>${valconcat([query, referenceTime, jitTime], 'td')}</tr>`;
      await sleep(1);
    }
  }
}
