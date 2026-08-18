/* Renders the diff table and drives the synced panes from window.VC_DATA.
 * No diff logic lives here: flags were precomputed per baseline by diff.py,
 * so switching baseline is a lookup. Pane sync is best-effort by design —
 * a failed locate must never break the table. */
(function () {
  "use strict";
  var data = window.VC_DATA;
  var baselineSelect = document.getElementById("baseline");
  var tableHost = document.getElementById("table");
  var panesHost = document.getElementById("panes");

  function esc(text) {
    var map = { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" };
    return String(text).replace(/[&<>"']/g, function (c) { return map[c]; });
  }

  data.tools.forEach(function (tool) {
    var option = document.createElement("option");
    option.value = tool;
    option.textContent = tool;
    baselineSelect.appendChild(option);
  });
  baselineSelect.value = data.tools.indexOf(data.defaultBaseline) >= 0
    ? data.defaultBaseline : data.tools[0];
  baselineSelect.addEventListener("change", renderTable);

  function rowRank(row, baseline) {
    var flags = row.flags[baseline] || {};
    var flagged = Object.keys(flags).length > 0;
    if (flagged && !row.expected) { return 0; }
    if (flagged) { return 1; }
    return 2;
  }

  function cellText(cell) {
    if (cell === null) { return "—"; }
    var text = cell.status + " · " + cell.duration.toFixed(2) + "s";
    text += cell.attachmentCount === null
      ? " · att n/a" : " · att " + cell.attachmentCount;
    return text;
  }

  function renderTable() {
    var baseline = baselineSelect.value;
    var rows = data.rows.slice().sort(function (a, b) {
      var rank = rowRank(a, baseline) - rowRank(b, baseline);
      return rank !== 0 ? rank : a.id.localeCompare(b.id);
    });
    var table = document.createElement("table");
    var head = document.createElement("tr");
    head.innerHTML = "<th>test</th>" + data.tools.map(function (tool) {
      return "<th>" + esc(tool) + (tool === baseline ? " (baseline)" : "") +
        "</th>";
    }).join("");
    table.appendChild(head);
    rows.forEach(function (row) {
      var tr = document.createElement("tr");
      var flags = row.flags[baseline] || {};
      if (Object.keys(flags).length) {
        tr.className = row.expected ? "expected" : "flagged";
      }
      if (row.expected && row.reason) { tr.title = row.reason; }
      var cells = "<td>" + esc(row.id) + "</td>";
      data.tools.forEach(function (tool) {
        var classes = [];
        if (flags[tool]) { classes.push("diff"); }
        if (row.cells[tool] === null) { classes.push("na"); }
        cells += "<td class='" + classes.join(" ") + "'" +
          (flags[tool] ? " title='" + esc(flags[tool].join(", ")) + "'" : "") +
          ">" + esc(cellText(row.cells[tool])) + "</td>";
      });
      tr.innerHTML = cells;
      tr.addEventListener("click", function () { syncPanes(row); });
      table.appendChild(tr);
    });
    tableHost.replaceChildren(table);
  }

  function paneTools() {
    var okToolsSet = {};
    data.cells.forEach(function (cell) {
      if (cell.status === "ok") { okToolsSet[cell.tool] = true; }
    });
    var okTools = Object.keys(okToolsSet);
    if (okTools.length <= 3) { return okTools; }

    var selected = [];
    var baselineIsOk = okToolsSet[data.defaultBaseline];
    if (baselineIsOk) {
      selected.push(data.defaultBaseline);
    } else {
      selected.push(okTools[0]);
    }

    var lastInOrder = null;
    for (var i = data.tools.length - 1; i >= 0; i--) {
      var tool = data.tools[i];
      if (okToolsSet[tool] && tool !== selected[0]) {
        lastInOrder = tool;
        break;
      }
    }
    if (lastInOrder) { selected.push(lastInOrder); }
    return selected;
  }

  function renderPanes() {
    if (window.location.protocol === "file:") {
      panesHost.innerHTML = "<p class='serve-note'>Panes need same-origin " +
        "iframes — rerun with --serve to enable them.</p>";
      return;
    }
    paneTools().forEach(function (tool) {
      var pane = document.createElement("div");
      pane.className = "pane";
      var select = document.createElement("select");
      data.cells.forEach(function (cell) {
        if (cell.status !== "ok") { return; }
        var option = document.createElement("option");
        option.value = cell.dir;
        option.textContent = cell.tool;
        if (cell.tool === tool) { option.selected = true; }
        select.appendChild(option);
      });
      var iframe = document.createElement("iframe");
      iframe.src = "../render/" + select.value + "/index.html";
      select.addEventListener("change", function () {
        iframe.src = "../render/" + select.value + "/index.html";
      });
      pane.appendChild(select);
      pane.appendChild(iframe);
      panesHost.appendChild(pane);
    });
  }

  function syncPanes(row) {
    var shortNames = {};
    (Object.keys(row.cells)).forEach(function (tool) {
      var cell = row.cells[tool];
      (cell ? cell.rawNames : []).forEach(function (raw) {
        var parts = raw.split("/");
        shortNames[parts[parts.length - 1]] = true;
      });
    });
    var needles = Object.keys(shortNames);
    panesHost.querySelectorAll("iframe").forEach(function (iframe) {
      try { locate(iframe.contentDocument, needles); } catch (error) {
        /* Cross-origin or template surprise: sync is best-effort. */
      }
    });
  }

  function locate(doc, needles) {
    if (!doc) { return; }
    var match = null;
    var walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_ELEMENT);
    while (walker.nextNode()) {
      var node = walker.currentNode;
      var text = (node.textContent || "").trim();
      var hit = needles.some(function (needle) {
        return text.indexOf(needle) !== -1;
      });
      if (hit && node.children.length === 0) { match = node; }
    }
    if (!match) { return; }
    if (match.offsetParent === null) {
      var ancestor = match.closest("[onclick]");
      if (ancestor) { ancestor.click(); }
    }
    match.scrollIntoView({ block: "center" });
    doc.querySelectorAll(".vc-flash").forEach(function (old) {
      old.classList.remove("vc-flash");
    });
    match.classList.add("vc-flash");
  }

  renderTable();
  renderPanes();
}());
