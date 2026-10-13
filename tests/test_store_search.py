import unittest
import urllib.error
from unittest.mock import patch

from carthage.store import _epic_search, _filter_epic_search, _filter_store_price, _steam_price, _store_search_status


def item(name, cents, discount=0):
    return {"name": name, "discount": discount, "offers": [{"cents": cents}]}


class EpicSearchFilterTests(unittest.TestCase):
    def setUp(self):
        self.items = [item("Free", 0), item("On sale", 750, 25), item("At cap", 1000), item("Over cap", 1500)]

    def test_numeric_price_cap(self):
        self.assertEqual([i["name"] for i in _filter_epic_search(self.items, "10")], ["Free", "On sale"])

    def test_under_cap_excludes_exact_boundary(self):
        self.assertNotIn("At cap", [i["name"] for i in _filter_epic_search(self.items, "10")])

    def test_steam_price_cap_excludes_exact_boundary(self):
        steam = [{"name": "At cap", "cents": 1000}, {"name": "Under cap", "cents": 999}]
        self.assertEqual([i["name"] for i in _filter_store_price(steam, "10")], ["Under cap"])

    def test_steam_upcoming_game_is_not_free(self):
        upcoming = _steam_price({}, False, {"is_coming_soon": True})
        self.assertEqual(upcoming["price"], "Coming Soon")
        self.assertTrue(upcoming["comingSoon"])
        self.assertEqual(_filter_store_price([upcoming], "free"), [])
        self.assertEqual(_filter_store_price([upcoming], "10"), [])

    def test_priced_preorder_uses_real_price_for_filters(self):
        preorder = _steam_price({"final_price_in_cents": 1500}, False, {"is_coming_soon": True})
        self.assertEqual(preorder["price"], "Coming Soon")
        self.assertEqual(preorder["cents"], 1500)
        self.assertEqual(_filter_store_price([preorder], "20"), [preorder])
        self.assertEqual(_filter_store_price([preorder], "10"), [])

    def test_steam_unavailable_price_is_not_free(self):
        unavailable = _steam_price({}, False, {})
        self.assertEqual(unavailable["price"], "")
        self.assertEqual(_filter_store_price([unavailable], "free"), [])

    def test_steam_explicit_free_price_is_free(self):
        free = _steam_price({}, True, {})
        self.assertEqual(free, {"price": "Free", "cents": 0, "comingSoon": False})

    def test_free_filter(self):
        self.assertEqual([i["name"] for i in _filter_epic_search(self.items, "free")], ["Free"])

    def test_sale_filter(self):
        self.assertEqual([i["name"] for i in _filter_epic_search(self.items, sale=True)], ["On sale"])

    def test_epic_request_failure_is_not_an_empty_success(self):
        with patch("carthage.store.shops.epic_search", side_effect=urllib.error.URLError("offline")):
            results, failed = _epic_search(lambda *_args: {}, "Hades", "US", lambda *_args: "")
        self.assertEqual(results, [])
        self.assertTrue(failed)

    def test_epic_request_success_is_not_a_failure(self):
        expected = [{"title": "Hades"}]
        with patch("carthage.store.shops.epic_search", return_value=expected):
            results, failed = _epic_search(lambda *_args: {}, "Hades", "US", lambda *_args: "")
        self.assertEqual(results, expected)
        self.assertFalse(failed)

    def test_combined_search_reports_available_partial_source(self):
        self.assertEqual(_store_search_status(True, False),
                         (False, "Steam search is unavailable; showing Epic results only."))
        self.assertEqual(_store_search_status(False, True),
                         (False, "Epic search is unavailable; showing Steam results only."))

    def test_combined_search_fails_only_when_both_sources_fail(self):
        self.assertEqual(_store_search_status(True, True), (True, ""))


if __name__ == "__main__":
    unittest.main()