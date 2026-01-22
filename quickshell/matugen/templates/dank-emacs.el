;;; dank-emacs-theme.el --- Enhanced theme using Matugen SCSS variables with dank16 colors

;; Copyright (C) 2025

;; Author: Generated (Enhanced)
;; Version: 1.3
;; Package-Requires: ((emacs "24.1"))
;; Keywords: faces

;;; Commentary:

;; An enhanced theme using Matugen SCSS variables integrated with dank16 colors:
;; - Rich color palette from dank16 for vibrant syntax highlighting
;; - Improved contrast and readability
;; - Better source block distinction with refined backgrounds
;; - Enhanced org-mode styling with hidden asterisks
;; - Superior visual hierarchy and modern aesthetics

;;; Code:

(deftheme dank-emacs "Enhanced theme using Matugen variables with dank16 color integration.")

;; Define all the color variables (replaced by template processor)
(let* ((bg "{{colors.background.dark.hex}}")
      (err "{{dank16.color1.dark.hex}}")  ; Red from dank16
      (err-container "{{colors.error_container.dark.hex}}")
      (on-background "{{colors.on_background.dark.hex}}")
      (on-err "{{colors.on_error.dark.hex}}")
      (on-err-container "{{colors.on_error_container.dark.hex}}")
      (on-primary "{{colors.on_primary.dark.hex}}")
      (on-primary-container "{{colors.on_primary_container.dark.hex}}")
      (on-secondary "{{colors.on_secondary.dark.hex}}")
      (on-secondary-container "{{colors.on_secondary_container.dark.hex}}")
      (on-surface "{{colors.on_surface.dark.hex}}")
      (on-surface-variant "{{colors.on_surface_variant.dark.hex}}")
      (on-tertiary "{{colors.on_tertiary.dark.hex}}")
      (on-tertiary-container "{{colors.on_tertiary_container.dark.hex}}")
      (outline-color "{{colors.outline.dark.hex}}")
      (outline-variant "{{colors.outline_variant.dark.hex}}")
      (primary "{{colors.primary.dark.hex}}")
      (primary-container "{{colors.primary_container.dark.hex}}")
      (secondary "{{colors.secondary.dark.hex}}")
      (secondary-container "{{colors.secondary_container.dark.hex}}")
      (shadow "{{colors.shadow.dark.hex}}")
      (surface "{{colors.surface.dark.hex}}")
      (surface-container "{{colors.surface_container_high.dark.hex}}")
      (surface-container-high "{{colors.surface_container_highest.dark.hex}}")
      (surface-container-highest "{{colors.surface_container_high.dark.hex}}")
      (surface-container-low "{{colors.surface_container_low.dark.hex}}")
      (surface-container-lowest "{{colors.surface_container_lowest.dark.hex}}")
      (surface-variant "{{colors.surface_variant.dark.hex}}")
      (tertiary "{{colors.tertiary.dark.hex}}")
      (tertiary-container "{{colors.tertiary_container.dark.hex}}")

      ;; Enhanced dank16 colors for better syntax highlighting
      (dank-red "{{dank16.color1.dark.hex}}")          ; Bright red
      (dank-red-alt "{{dank16.color9.dark.hex}}")      ; Alternative red
      (dank-green "{{dank16.color2.dark.hex}}")        ; Vibrant green
      (dank-green-bright "{{dank16.color10.dark.hex}}") ; Bright green
      (dank-yellow "{{dank16.color3.dark.hex}}")       ; Warm yellow
      (dank-yellow-bright "{{dank16.color11.dark.hex}}") ; Bright yellow
      (dank-blue "{{dank16.color4.dark.hex}}")         ; Blue-green
      (dank-magenta "{{dank16.color5.dark.hex}}")      ; Teal-magenta
      (dank-cyan "{{dank16.color6.dark.hex}}")         ; Bright cyan
      (dank-cyan-bright "{{dank16.color12.dark.hex}}") ; Brightest cyan
      (dank-cyan-dark "{{dank16.color13.dark.hex}}")   ; Dark cyan
      (dank-teal "{{dank16.color14.dark.hex}}")        ; Dark teal
      (dank-fg "{{dank16.color7.dark.hex}}")           ; Light foreground
      (dank-gray "{{dank16.color8.dark.hex}}")         ; Gray
      (dank-white "{{dank16.color15.dark.hex}}")       ; White

      ;; Map success colors to green
      (success "{{dank16.color2.dark.hex}}")
      (on-success "{{colors.on_tertiary.dark.hex}}")
      (success-container "{{colors.tertiary_container.dark.hex}}")
      (on-success-container "{{colors.on_tertiary_container.dark.hex}}")

      ;; Map fixed colors
      (primary-fixed "{{colors.primary_fixed.dark.hex}}")
      (primary-fixed-dim "{{colors.primary_fixed_dim.dark.hex}}")
      (secondary-fixed "{{colors.secondary_fixed.dark.hex}}")
      (secondary-fixed-dim "{{colors.secondary_fixed_dim.dark.hex}}")
      (tertiary-fixed "{{colors.tertiary_fixed.dark.hex}}")
      (tertiary-fixed-dim "{{colors.tertiary_fixed_dim.dark.hex}}")
      (on-primary-fixed "{{colors.on_primary_fixed.dark.hex}}")
      (on-primary-fixed-variant "{{colors.on_primary_fixed_variant.dark.hex}}")
      (on-secondary-fixed "{{colors.on_secondary_fixed.dark.hex}}")
      (on-secondary-fixed-variant "{{colors.on_secondary_fixed_variant.dark.hex}}")
      (on-tertiary-fixed "{{colors.on_tertiary_fixed.dark.hex}}")
      (on-tertiary-fixed-variant "{{colors.on_tertiary_fixed_variant.dark.hex}}")

      ;; Map inverse colors
      (inverse-on-surface "{{colors.inverse_on_surface.dark.hex}}")
      (inverse-primary "{{colors.inverse_primary.dark.hex}}")
      (inverse-surface "{{colors.inverse_surface.dark.hex}}")

      ;; Terminal colors from dank16
      (term0 "{{dank16.color0.dark.hex}}")
      (term1 "{{dank16.color1.dark.hex}}")
      (term2 "{{dank16.color2.dark.hex}}")
      (term3 "{{dank16.color3.dark.hex}}")
      (term4 "{{dank16.color4.dark.hex}}")
      (term5 "{{dank16.color5.dark.hex}}")
      (term6 "{{dank16.color6.dark.hex}}")
      (term7 "{{dank16.color7.dark.hex}}")
      (term8 "{{dank16.color8.dark.hex}}")
      (term9 "{{dank16.color9.dark.hex}}")
      (term10 "{{dank16.color10.dark.hex}}")
      (term11 "{{dank16.color11.dark.hex}}")
      (term12 "{{dank16.color12.dark.hex}}")
      (term13 "{{dank16.color13.dark.hex}}")
      (term14 "{{dank16.color14.dark.hex}}")
      (term15 "{{dank16.color15.dark.hex}}"))

  (custom-theme-set-faces
   'dank-emacs
   ;; Basic faces
   `(default ((t (:background ,bg :foreground ,on-background))))
   `(cursor ((t (:background ,dank-cyan-bright))))
   `(highlight ((t (:background ,primary-container :foreground ,on-primary-container))))
   `(region ((t (:background ,primary-container :foreground ,dank-cyan-bright :extend t))))
   `(secondary-selection ((t (:background ,secondary-container :foreground ,on-secondary-container :extend t))))
   `(isearch ((t (:background ,dank-yellow :foreground ,bg :weight bold))))
   `(lazy-highlight ((t (:background ,secondary-container :foreground ,dank-yellow-bright))))
   `(vertical-border ((t (:foreground ,surface-variant))))
   `(border ((t (:background ,surface-variant :foreground ,surface-variant))))
   `(fringe ((t (:background ,surface :foreground ,dank-gray))))
   `(shadow ((t (:foreground ,dank-gray))))
   `(link ((t (:foreground ,dank-cyan-bright :underline t))))
   `(link-visited ((t (:foreground ,dank-magenta :underline t))))
   `(success ((t (:foreground ,success))))
   `(warning ((t (:foreground ,dank-yellow))))
   `(error ((t (:foreground ,err))))
   `(match ((t (:background ,dank-yellow :foreground ,bg :weight bold))))

   ;; Font-lock - enhanced with dank16 colors for vibrant syntax highlighting
   `(font-lock-builtin-face ((t (:foreground ,dank-cyan-bright))))
   `(font-lock-comment-face ((t (:foreground ,dank-gray :slant italic))))
   `(font-lock-comment-delimiter-face ((t (:foreground ,outline-variant))))
   `(font-lock-constant-face ((t (:foreground ,dank-yellow-bright :weight bold))))
   `(font-lock-doc-face ((t (:foreground ,dank-fg :slant italic))))
   `(font-lock-function-name-face ((t (:foreground ,dank-cyan :weight bold))))
   `(font-lock-keyword-face ((t (:foreground ,dank-red-alt :weight bold))))
   `(font-lock-string-face ((t (:foreground ,dank-green))))
   `(font-lock-type-face ((t (:foreground ,dank-yellow))))
   `(font-lock-variable-name-face ((t (:foreground ,dank-fg))))
   `(font-lock-warning-face ((t (:foreground ,err :weight bold))))
   `(font-lock-preprocessor-face ((t (:foreground ,dank-teal))))
   `(font-lock-negation-char-face ((t (:foreground ,dank-red))))

   ;; Show paren
   `(show-paren-match ((t (:background ,primary-container :foreground ,dank-cyan-bright :weight bold))))
   `(show-paren-mismatch ((t (:background ,err-container :foreground ,on-err-container :weight bold))))

   ;; Mode line - improved status bar styling
   `(mode-line ((t (:background ,surface-container :foreground ,on-surface :box nil))))
   `(mode-line-inactive ((t (:background ,surface :foreground ,dank-gray :box nil))))
   `(mode-line-buffer-id ((t (:foreground ,dank-cyan :weight bold))))
   `(mode-line-emphasis ((t (:foreground ,dank-cyan :weight bold))))
   `(mode-line-highlight ((t (:foreground ,dank-cyan-bright :box nil))))

   ;; Improved Source blocks - seamless integration
   `(org-block ((t (:background ,surface-container-low :extend t :inherit fixed-pitch))))
   `(org-block-begin-line ((t (:background ,surface-container-low :foreground ,dank-teal :extend t :slant italic :inherit fixed-pitch))))
   `(org-block-end-line ((t (:background ,surface-container-low :foreground ,dank-teal :extend t :slant italic :inherit fixed-pitch))))
   `(org-code ((t (:background ,surface-container-low :foreground ,dank-yellow-bright :inherit fixed-pitch))))
   `(org-verbatim ((t (:background ,surface-container-low :foreground ,dank-cyan :inherit fixed-pitch))))
   `(org-meta-line ((t (:foreground ,dank-gray :slant italic))))

   ;; Org mode with enhanced colors and hidden asterisks
   `(org-level-1 ((t (:foreground ,dank-cyan :weight bold :height 1.2))))
   `(org-level-2 ((t (:foreground ,dank-blue :weight bold :height 1.1))))
   `(org-level-3 ((t (:foreground ,dank-magenta :weight bold))))
   `(org-level-4 ((t (:foreground ,dank-green :weight bold))))
   `(org-level-5 ((t (:foreground ,dank-yellow :weight bold))))
   `(org-level-6 ((t (:foreground ,dank-cyan-bright :weight bold))))
   `(org-level-7 ((t (:foreground ,dank-red-alt :weight bold))))
   `(org-level-8 ((t (:foreground ,dank-teal :weight bold))))
   `(org-document-title ((t (:foreground ,dank-cyan :weight bold :height 1.3))))
   `(org-document-info ((t (:foreground ,dank-blue))))
   `(org-todo ((t (:foreground ,dank-red :weight bold))))
   `(org-done ((t (:foreground ,success :weight bold))))
   `(org-headline-done ((t (:foreground ,dank-gray))))
   `(org-hide ((t (:foreground ,bg))))
   `(org-ellipsis ((t (:foreground ,dank-blue :underline nil))))
   `(org-table ((t (:foreground ,dank-magenta :inherit fixed-pitch))))
   `(org-formula ((t (:foreground ,dank-yellow-bright :inherit fixed-pitch))))
   `(org-checkbox ((t (:foreground ,dank-cyan :weight bold :inherit fixed-pitch))))
   `(org-date ((t (:foreground ,dank-teal :underline t))))
   `(org-special-keyword ((t (:foreground ,dank-gray :slant italic))))
   `(org-tag ((t (:foreground ,dank-gray :weight normal))))

   ;; Magit with enhanced diff colors
   `(magit-section-highlight ((t (:background ,surface-container-low))))
   `(magit-diff-hunk-heading ((t (:background ,surface-container :foreground ,dank-gray))))
   `(magit-diff-hunk-heading-highlight ((t (:background ,surface-container-high :foreground ,on-surface))))
   `(magit-diff-context ((t (:foreground ,dank-gray))))
   `(magit-diff-context-highlight ((t (:background ,surface-container-low :foreground ,on-surface))))
   `(magit-diff-added ((t (:background ,success-container :foreground ,dank-green-bright))))
   `(magit-diff-added-highlight ((t (:background ,success-container :foreground ,dank-green-bright :weight bold))))
   `(magit-diff-removed ((t (:background ,err-container :foreground ,dank-red-alt))))
   `(magit-diff-removed-highlight ((t (:background ,err-container :foreground ,dank-red-alt :weight bold))))
   `(magit-hash ((t (:foreground ,dank-gray))))
   `(magit-branch-local ((t (:foreground ,dank-blue :weight bold))))
   `(magit-branch-remote ((t (:foreground ,dank-cyan :weight bold))))

   ;; Company
   `(company-tooltip ((t (:background ,surface-container :foreground ,on-surface))))
   `(company-tooltip-selection ((t (:background ,primary-container :foreground ,dank-cyan-bright))))
   `(company-tooltip-common ((t (:foreground ,dank-cyan))))
   `(company-tooltip-common-selection ((t (:foreground ,dank-cyan-bright :weight bold))))
   `(company-tooltip-annotation ((t (:foreground ,dank-yellow))))
   `(company-scrollbar-fg ((t (:background ,dank-cyan))))
   `(company-scrollbar-bg ((t (:background ,surface-variant))))
   `(company-preview ((t (:foreground ,dank-gray :slant italic))))
   `(company-preview-common ((t (:foreground ,dank-cyan :slant italic))))

   ;; Ido
   `(ido-first-match ((t (:foreground ,dank-cyan :weight bold))))
   `(ido-only-match ((t (:foreground ,dank-green :weight bold))))
   `(ido-subdir ((t (:foreground ,dank-blue))))
   `(ido-indicator ((t (:foreground ,dank-red))))
   `(ido-virtual ((t (:foreground ,dank-gray))))

   ;; Helm
   `(helm-selection ((t (:background ,primary-container :foreground ,dank-cyan-bright))))
   `(helm-match ((t (:foreground ,dank-cyan :weight bold))))
   `(helm-source-header ((t (:background ,surface-container-high :foreground ,dank-cyan :weight bold :height 1.1))))
   `(helm-candidate-number ((t (:foreground ,dank-yellow :weight bold))))
   `(helm-ff-directory ((t (:foreground ,dank-cyan :weight bold))))
   `(helm-ff-file ((t (:foreground ,on-surface))))
   `(helm-ff-executable ((t (:foreground ,dank-green))))

   ;; corfu
   `(corfu-default ((t (:background ,surface-container :foreground ,on-surface))))
   `(corfu-current ((t (:background ,primary-container :foreground ,dank-cyan-bright))))

   ;; Which-key
   `(which-key-key-face ((t (:foreground ,dank-cyan :weight bold))))
   `(which-key-separator-face ((t (:foreground ,outline-variant))))
   `(which-key-command-description-face ((t (:foreground ,on-surface))))
   `(which-key-group-description-face ((t (:foreground ,dank-blue))))
   `(which-key-special-key-face ((t (:foreground ,dank-yellow :weight bold))))

   ;; Line numbers
   `(line-number ((t (:foreground ,dank-gray :inherit fixed-pitch))))
   `(line-number-current-line ((t (:foreground ,dank-cyan :weight bold :inherit fixed-pitch))))

   ;; Parenthesis matching
   `(sp-show-pair-match-face ((t (:background ,primary-container :foreground ,dank-cyan-bright))))
   `(sp-show-pair-mismatch-face ((t (:background ,err-container :foreground ,on-err-container))))

   ;; Rainbow delimiters - vibrant colors
   `(rainbow-delimiters-depth-1-face ((t (:foreground ,dank-cyan))))
   `(rainbow-delimiters-depth-2-face ((t (:foreground ,dank-yellow))))
   `(rainbow-delimiters-depth-3-face ((t (:foreground ,dank-green))))
   `(rainbow-delimiters-depth-4-face ((t (:foreground ,dank-blue))))
   `(rainbow-delimiters-depth-5-face ((t (:foreground ,dank-magenta))))
   `(rainbow-delimiters-depth-6-face ((t (:foreground ,dank-cyan-bright))))
   `(rainbow-delimiters-depth-7-face ((t (:foreground ,dank-yellow-bright))))
   `(rainbow-delimiters-depth-8-face ((t (:foreground ,dank-green-bright))))
   `(rainbow-delimiters-depth-9-face ((t (:foreground ,dank-red-alt))))
   `(rainbow-delimiters-mismatched-face ((t (:foreground ,err :weight bold))))
   `(rainbow-delimiters-unmatched-face ((t (:foreground ,err :weight bold))))

   ;; Dired
   `(dired-directory ((t (:foreground ,dank-cyan :weight bold))))
   `(dired-ignored ((t (:foreground ,dank-gray))))
   `(dired-flagged ((t (:foreground ,dank-red))))
   `(dired-marked ((t (:foreground ,dank-yellow :weight bold))))
   `(dired-symlink ((t (:foreground ,dank-magenta :slant italic))))
   `(dired-header ((t (:foreground ,dank-cyan :weight bold :height 1.1))))

   ;; Terminal colors
   `(term-color-black ((t (:foreground ,term0 :background ,term0))))
   `(term-color-red ((t (:foreground ,term1 :background ,term1))))
   `(term-color-green ((t (:foreground ,term2 :background ,term2))))
   `(term-color-yellow ((t (:foreground ,term3 :background ,term3))))
   `(term-color-blue ((t (:foreground ,term4 :background ,term4))))
   `(term-color-magenta ((t (:foreground ,term5 :background ,term5))))
   `(term-color-cyan ((t (:foreground ,term6 :background ,term6))))
   `(term-color-white ((t (:foreground ,term7 :background ,term7))))

   ;; EShell
   `(eshell-prompt ((t (:foreground ,dank-cyan :weight bold))))
   `(eshell-ls-directory ((t (:foreground ,dank-cyan :weight bold))))
   `(eshell-ls-symlink ((t (:foreground ,dank-magenta :slant italic))))
   `(eshell-ls-executable ((t (:foreground ,dank-green))))
   `(eshell-ls-archive ((t (:foreground ,dank-yellow))))
   `(eshell-ls-backup ((t (:foreground ,dank-gray))))
   `(eshell-ls-clutter ((t (:foreground ,dank-red))))
   `(eshell-ls-missing ((t (:foreground ,dank-red))))
   `(eshell-ls-product ((t (:foreground ,on-surface-variant))))
   `(eshell-ls-readonly ((t (:foreground ,dank-gray))))
   `(eshell-ls-special ((t (:foreground ,dank-blue))))
   `(eshell-ls-unreadable ((t (:foreground ,dank-gray))))

   ;; Improved markdown mode
   `(markdown-header-face ((t (:foreground ,dank-cyan :weight bold))))
   `(markdown-header-face-1 ((t (:foreground ,dank-cyan :weight bold :height 1.2))))
   `(markdown-header-face-2 ((t (:foreground ,dank-blue :weight bold :height 1.1))))
   `(markdown-header-face-3 ((t (:foreground ,dank-magenta :weight bold))))
   `(markdown-header-face-4 ((t (:foreground ,dank-green :weight bold))))
   `(markdown-inline-code-face ((t (:foreground ,dank-yellow-bright :background ,surface-container-low :inherit fixed-pitch))))
   `(markdown-code-face ((t (:background ,surface-container-low :extend t :inherit fixed-pitch))))
   `(markdown-pre-face ((t (:background ,surface-container-low :inherit fixed-pitch))))
   `(markdown-table-face ((t (:foreground ,dank-magenta :inherit fixed-pitch))))

   ;; Web mode
   `(web-mode-html-tag-face ((t (:foreground ,dank-cyan))))
   `(web-mode-html-tag-bracket-face ((t (:foreground ,dank-gray))))
   `(web-mode-html-attr-name-face ((t (:foreground ,dank-yellow))))
   `(web-mode-html-attr-value-face ((t (:foreground ,dank-green))))
   `(web-mode-css-selector-face ((t (:foreground ,dank-cyan))))
   `(web-mode-css-property-name-face ((t (:foreground ,dank-blue))))
   `(web-mode-css-string-face ((t (:foreground ,dank-green))))

   ;; Flycheck
   `(flycheck-error ((t (:underline (:style wave :color ,err)))))
   `(flycheck-warning ((t (:underline (:style wave :color ,dank-yellow)))))
   `(flycheck-info ((t (:underline (:style wave :color ,dank-blue)))))
   `(flycheck-fringe-error ((t (:foreground ,err))))
   `(flycheck-fringe-warning ((t (:foreground ,dank-yellow))))
   `(flycheck-fringe-info ((t (:foreground ,dank-blue))))

   ;; Mini-buffer customization
   `(minibuffer-prompt ((t (:foreground ,dank-cyan :weight bold))))

   ;; Improved search highlighting
   `(lsp-face-highlight-textual ((t (:background ,primary-container :foreground ,dank-cyan-bright :weight bold))))
   `(lsp-face-highlight-read ((t (:background ,secondary-container :foreground ,dank-yellow-bright :weight bold))))
   `(lsp-face-highlight-write ((t (:background ,tertiary-container :foreground ,dank-green-bright :weight bold))))

   ;; Info and help modes
   `(info-title-1 ((t (:foreground ,dank-cyan :weight bold :height 1.3))))
   `(info-title-2 ((t (:foreground ,dank-blue :weight bold :height 1.2))))
   `(info-title-3 ((t (:foreground ,dank-magenta :weight bold :height 1.1))))
   `(info-title-4 ((t (:foreground ,dank-green :weight bold))))
   `(Info-quoted ((t (:foreground ,dank-yellow))))
   `(info-menu-header ((t (:foreground ,dank-cyan :weight bold))))
   `(info-menu-star ((t (:foreground ,dank-cyan))))
   `(info-node ((t (:foreground ,dank-blue :weight bold))))

   ;; Tabs
   `(tab-bar ((t (:background ,surface-container :foreground ,on-surface :box nil))))
   `(tab-bar-tab ((t (:background ,surface-container-high :foreground ,dank-cyan :weight bold :box nil))))
   `(tab-bar-tab-inactive ((t (:background ,surface :foreground ,dank-gray :box nil))))

   `(tab-line ((t (:background ,surface-container :foreground ,on-surface :box nil))))
   `(tab-line-tab ((t (:background ,surface :foreground ,dank-gray :box nil))))
   `(tab-line-tab-current ((t (:background ,surface-container-high :foreground ,dank-cyan :weight bold :box nil))))
   `(tab-line-tab-inactive ((t (:background ,surface :foreground ,dank-gray :box nil))))
   `(tab-line-highlight ((t (:background ,surface-container-highest :foreground ,dank-cyan-bright))))

   `(centaur-tabs-default ((t (:background ,surface-container :foreground ,on-surface))))
   `(centaur-tabs-selected ((t (:background ,surface-container-high :foreground ,dank-cyan :weight bold))))
   `(centaur-tabs-unselected ((t (:background ,surface :foreground ,dank-gray))))
   `(centaur-tabs-selected-modified ((t (:background ,surface-container-high :foreground ,dank-yellow :weight bold))))
   `(centaur-tabs-unselected-modified ((t (:background ,surface :foreground ,dank-yellow))))
   `(centaur-tabs-active-bar-face ((t (:background ,dank-cyan))))

   ;; Fixed-pitch faces
   `(fixed-pitch ((t (:family "monospace"))))
   `(fixed-pitch-serif ((t (:family "monospace serif"))))

   ;; Variable-pitch face
   `(variable-pitch ((t (:family "sans serif"))))
   ))

;; Add org-mode hooks for hiding leading stars
(with-eval-after-load 'org
  (setq org-hide-leading-stars t)
  (setq org-startup-indented t))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'dank-emacs)
;;; dank-emacs-theme.el ends here
