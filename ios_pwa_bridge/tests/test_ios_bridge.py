"""Testes Automatizados do Motor e Servidor iOS (PWA + Endpoint de Atalhos do iPhone)."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock

_BRIDGE_DIR = Path(__file__).resolve().parents[1]
if str(_BRIDGE_DIR) not in sys.path:
    sys.path.insert(0, str(_BRIDGE_DIR))

from app import IOSTranslationEngine


class TestIOSBridgeAndEngine(unittest.TestCase):
    def test_ios_language_detection_and_offline_fallback(self) -> None:
        engine = IOSTranslationEngine()
        phrase = "Você é muito lindo. Topa receber um dinheiro para sairmos?"
        self.assertEqual(engine.detect_language(phrase), "PT-BR")

        mock_client = MagicMock()
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = [
            [["You are very handsome. Would you like to get some money for us to go out?", phrase, None, None, 10]],
            None,
            "pt",
        ]
        mock_client.get.return_value = mock_resp

        res = engine.translate(text=phrase, target_lang="EN-US", http_client=mock_client)
        self.assertEqual(
            res["translated_text"],
            "You are very handsome. Would you like to get some money for us to go out?",
        )
        self.assertEqual(res["detected_source_lang"], "PT-BR")

    def test_ios_glossary_protection(self) -> None:
        engine = IOSTranslationEngine()
        mock_client = MagicMock()
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = [
            [["Report on __UTGLOSS0__ in __UTGLOSS1__", "Relatório sobre __UTGLOSS0__ no __UTGLOSS1__"]],
            None,
            "pt",
        ]
        mock_client.get.return_value = mock_resp

        res = engine.translate(
            text="Relatório sobre áreas contaminadas no EQuIS",
            target_lang="EN-US",
            http_client=mock_client,
        )
        self.assertEqual(res["translated_text"], "Report on contaminated sites in EQuIS")


if __name__ == "__main__":
    unittest.main()
