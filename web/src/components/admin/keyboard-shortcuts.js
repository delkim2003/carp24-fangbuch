/**
 * Keyboard Shortcuts for Carp24 Admin Pages
 *
 * Usage:
 *   import AdminKeyboardShortcuts from '../../components/admin/keyboard-shortcuts.js';
 *   AdminKeyboardShortcuts.init({
 *     searchSelector: '#search-input',
 *     onEscape: () => closeModal(),
 *     onNew: () => openNewForm(),
 *     shortcuts: [
 *       { key: 'g h', desc: 'Zur Startseite', handler: () => window.location.href = '/' }
 *     ]
 *   });
 */

var AdminKeyboardShortcuts = (function () {
  'use strict';

  function init(config) {
    config = config || {};
    var searchSelector = config.searchSelector || null;
    var onEscape = config.onEscape || null;
    var onNew = config.onNew || null;
    var customShortcuts = config.shortcuts || [];

    // ── Build help items ────────────────────────────────
    var helpItems = [];

    if (searchSelector) {
      var searchEl = document.querySelector(searchSelector);
      if (searchEl) {
        helpItems.push({ keys: 'Ctrl+F / /', desc: 'Suche fokussieren' });
      }
    }

    helpItems.push({ keys: 'Esc', desc: 'Dialog / Drawer schliessen' });

    if (onNew) {
      helpItems.push({ keys: 'N', desc: 'Neu erstellen' });
    }

    customShortcuts.forEach(function (s) {
      helpItems.push({ keys: s.key, desc: s.desc });
    });

    // ── Create help tooltip ──────────────────────────────
    var helpBtn = document.createElement('button');
    helpBtn.type = 'button';
    helpBtn.id = 'kbd-help-btn';
    helpBtn.setAttribute('aria-label', 'Tastaturkürzel');
    helpBtn.title = 'Tastaturkürzel anzeigen';
    helpBtn.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>';
    helpBtn.style.cssText = 'position:fixed;bottom:1.5rem;right:1.5rem;z-index:9998;width:40px;height:40px;border-radius:9999px;background:var(--color-primary,#1a73e8);color:white;border:none;cursor:pointer;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 8px rgba(0,0,0,0.2);opacity:0.85;transition:opacity 0.2s,transform 0.2s;';
    helpBtn.addEventListener('mouseenter', function () { helpBtn.style.opacity = '1'; helpBtn.style.transform = 'scale(1.1)'; });
    helpBtn.addEventListener('mouseleave', function () { helpBtn.style.opacity = '0.85'; helpBtn.style.transform = 'scale(1)'; });

    var helpPanel = document.createElement('div');
    helpPanel.id = 'kbd-help-panel';
    helpPanel.style.cssText = 'position:fixed;bottom:5rem;right:1.5rem;z-index:9999;background:var(--color-surface-container-high,#1e1e1e);color:var(--color-on-surface,#e0e0e0);border:1px solid var(--color-outline,#444);border-radius:12px;padding:1rem;min-width:220px;box-shadow:0 8px 24px rgba(0,0,0,0.4);display:none;font-size:0.875rem;line-height:1.5;';

    var title = document.createElement('p');
    title.textContent = 'Tastaturkürzel';
    title.style.cssText = 'font-weight:600;margin:0 0 0.75rem 0;font-size:0.8rem;text-transform:uppercase;letter-spacing:0.05em;opacity:0.7;';
    helpPanel.appendChild(title);

    var list = document.createElement('div');
    list.style.cssText = 'display:flex;flex-direction:column;gap:0.4rem;';

    helpItems.forEach(function (item) {
      var row = document.createElement('div');
      row.style.cssText = 'display:flex;justify-content:space-between;align-items:center;gap:1rem;';

      var kbd = document.createElement('kbd');
      kbd.textContent = item.keys;
      kbd.style.cssText = 'background:var(--color-surface-container-highest,#333);padding:2px 8px;border-radius:4px;font-family:monospace;font-size:0.75rem;white-space:nowrap;border:1px solid var(--color-outline,#555);';

      var desc = document.createElement('span');
      desc.textContent = item.desc;
      desc.style.cssText = 'font-size:0.8rem;opacity:0.85;';

      row.appendChild(kbd);
      row.appendChild(desc);
      list.appendChild(row);
    });

    helpPanel.appendChild(list);

    // Dismiss note
    var dismissNote = document.createElement('p');
    dismissNote.textContent = 'Drücke ? um dieses Fenster zu schliessen.';
    dismissNote.style.cssText = 'font-size:0.7rem;opacity:0.5;margin:0.75rem 0 0 0;text-align:center;';
    helpPanel.appendChild(dismissNote);

    document.body.appendChild(helpBtn);
    document.body.appendChild(helpPanel);

    // ── Toggle help panel ──────────────────────────────
    var helpVisible = false;

    function toggleHelp() {
      helpVisible = !helpVisible;
      helpPanel.style.display = helpVisible ? 'block' : 'none';
    }

    helpBtn.addEventListener('click', toggleHelp);

    // ── Keyboard handler ─────────────────────────────────
    function handleKeyDown(e) {
      // Ignore if user is typing in an input / textarea / select / contenteditable
      var tag = e.target.tagName;
      var isEditing = tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || e.target.isContentEditable;

      var key = e.key;
      var ctrl = e.ctrlKey || e.metaKey;

      // ? toggles help (always works)
      if (key === '?' && !isEditing) {
        e.preventDefault();
        toggleHelp();
        return;
      }

      // Ctrl+F or / → focus search (only when not editing)
      if ((ctrl && key === 'f') || (key === '/' && !ctrl && !isEditing)) {
        e.preventDefault();
        if (searchSelector) {
          var searchEl = document.querySelector(searchSelector);
          if (searchEl) {
            searchEl.focus();
            return;
          }
        }
      }

      // N → new action (only when not editing)
      if ((key === 'n' || key === 'N') && !ctrl && !isEditing && onNew) {
        e.preventDefault();
        onNew();
        return;
      }

      // Escape → close modals/drawers
      if (key === 'Escape' && onEscape) {
        onEscape();
        return;
      }
    }

    document.addEventListener('keydown', handleKeyDown);

    // ── Return public API for cleanup ────────────────────
    return {
      destroy: function () {
        document.removeEventListener('keydown', handleKeyDown);
        if (helpBtn && helpBtn.parentNode) helpBtn.parentNode.removeChild(helpBtn);
        if (helpPanel && helpPanel.parentNode) helpPanel.parentNode.removeChild(helpPanel);
      },
      toggleHelp: toggleHelp,
    };
  }

  return { init: init };
})();

export default AdminKeyboardShortcuts;