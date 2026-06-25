"use client";

import { useEffect, useState, useCallback } from "react";
import { Plus, Pencil, Trash2, RefreshCw, MapPin, Building } from "lucide-react";
import { adminApi, State, City } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

const EMPTY_STATE_FORM = { name_en: "", name_ar: "" };
const EMPTY_CITY_FORM = { name_en: "", name_ar: "" };

export default function StatesCitiesPage() {
  const { t, lang } = useLang();
  
  // States list and state form
  const [states, setStates] = useState<State[]>([]);
  const [selectedState, setSelectedState] = useState<State | null>(null);
  const [loadingStates, setLoadingStates] = useState(true);
  const [showStateModal, setShowStateModal] = useState(false);
  const [editState, setEditState] = useState<State | null>(null);
  const [stateForm, setStateForm] = useState({ ...EMPTY_STATE_FORM });
  const [savingState, setSavingState] = useState(false);
  const [stateSearch, setStateSearch] = useState("");

  // Cities list and city form
  const [cities, setCities] = useState<City[]>([]);
  const [loadingCities, setLoadingCities] = useState(false);
  const [showCityModal, setShowCityModal] = useState(false);
  const [editCity, setEditCity] = useState<City | null>(null);
  const [cityForm, setCityForm] = useState({ ...EMPTY_CITY_FORM });
  const [savingCity, setSavingCity] = useState(false);
  const [citySearch, setCitySearch] = useState("");

  const [error, setError] = useState("");

  // Load States
  const loadStates = useCallback(async () => {
    setLoadingStates(true);
    try {
      const res = await adminApi.listStates();
      setStates(res);
      // Keep selection if it still exists, else select the first state
      if (res.length > 0) {
        setSelectedState(prev => {
          const found = res.find(s => s.id === prev?.id);
          return found || res[0];
        });
      } else {
        setSelectedState(null);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToLoad"));
    } finally {
      setLoadingStates(false);
    }
  }, [t]);

  // Load Cities of the selected State
  const loadCities = useCallback(async (stateId: string) => {
    setLoadingCities(true);
    try {
      const res = await adminApi.listCities({ state_id: stateId });
      setCities(res);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToLoad"));
    } finally {
      setLoadingCities(false);
    }
  }, [t]);

  // Load states on mount
  useEffect(() => {
    loadStates();
  }, [loadStates]);

  // Load cities whenever selected state changes
  useEffect(() => {
    if (selectedState) {
      loadCities(selectedState.id);
    } else {
      setCities([]);
    }
  }, [selectedState, loadCities]);

  const handleRefreshAll = () => {
    loadStates();
    if (selectedState) {
      loadCities(selectedState.id);
    }
  };

  // State Modals / Actions
  const openCreateState = () => {
    setEditState(null);
    setStateForm({ ...EMPTY_STATE_FORM });
    setShowStateModal(true);
  };

  const openEditState = (s: State, e: React.MouseEvent) => {
    e.stopPropagation();
    setEditState(s);
    setStateForm({
      name_en: s.name_en,
      name_ar: s.name_ar,
    });
    setShowStateModal(true);
  };

  const handleStateSubmit = async () => {
    setSavingState(true);
    try {
      if (editState) {
        await adminApi.updateState(editState.id, stateForm);
      } else {
        await adminApi.createState(stateForm);
      }
      setShowStateModal(false);
      loadStates();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    } finally {
      setSavingState(false);
    }
  };

  const handleStateDelete = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!confirm(t("deleteStateConfirm"))) return;
    try {
      await adminApi.deleteState(id);
      if (selectedState?.id === id) {
        setSelectedState(null);
      }
      loadStates();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToDelete"));
    }
  };

  // City Modals / Actions
  const openCreateCity = () => {
    if (!selectedState) return;
    setEditCity(null);
    setCityForm({ ...EMPTY_CITY_FORM });
    setShowCityModal(true);
  };

  const openEditCity = (c: City) => {
    setEditCity(c);
    setCityForm({
      name_en: c.name_en,
      name_ar: c.name_ar,
    });
    setShowCityModal(true);
  };

  const handleCitySubmit = async () => {
    if (!selectedState) return;
    setSavingCity(true);
    try {
      if (editCity) {
        await adminApi.updateCity(editCity.id, {
          state_id: selectedState.id,
          name_en: cityForm.name_en,
          name_ar: cityForm.name_ar,
        });
      } else {
        await adminApi.createCity({
          state_id: selectedState.id,
          name_en: cityForm.name_en,
          name_ar: cityForm.name_ar,
        });
      }
      setShowCityModal(false);
      loadCities(selectedState.id);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    } finally {
      setSavingCity(false);
    }
  };

  const handleCityDelete = async (id: string) => {
    if (!confirm(t("deleteCityConfirm"))) return;
    try {
      await adminApi.deleteCity(id);
      if (selectedState) {
        loadCities(selectedState.id);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToDelete"));
    }
  };

  // Filters
  const filteredStates = states.filter(s =>
    s.name_en.toLowerCase().includes(stateSearch.toLowerCase()) ||
    s.name_ar.includes(stateSearch)
  );

  const filteredCities = cities.filter(c =>
    c.name_en.toLowerCase().includes(citySearch.toLowerCase()) ||
    c.name_ar.includes(citySearch)
  );

  return (
    <div>
      {error && <div className="alert alert-error">{error}</div>}

      {/* Main Split Grid */}
      <div style={{
        display: "grid",
        gridTemplateColumns: "1fr 1.2fr",
        gap: 24,
        alignItems: "start",
      }}>
        {/* Left Side: States Column */}
        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h2 style={{ fontSize: 16, fontWeight: 700, display: "flex", alignItems: "center", gap: 8 }}>
              <MapPin size={18} className="text-primary" />
              {t("states")}
            </h2>
            <div style={{ display: "flex", gap: 8 }}>
              <button className="btn btn-ghost btn-icon btn-sm" onClick={handleRefreshAll} title={t("refresh")}>
                <RefreshCw size={14} />
              </button>
              <button id="add-state-btn" className="btn btn-primary btn-sm" onClick={openCreateState}>
                <Plus size={14} /> {t("addState")}
              </button>
            </div>
          </div>

          <input
            className="input btn-sm"
            style={{ marginBottom: 14 }}
            placeholder={t("searchPlaceholder")}
            value={stateSearch}
            onChange={e => setStateSearch(e.target.value)}
          />

          {loadingStates ? (
            <div style={{ padding: 40, display: "flex", justifyContent: "center" }}>
              <div className="spinner" style={{ width: 28, height: 28 }} />
            </div>
          ) : (
            <div style={{
              display: "flex",
              flexDirection: "column",
              gap: 8,
              maxHeight: "500px",
              overflowY: "auto",
            }}>
              {filteredStates.map(state => {
                const isActive = selectedState?.id === state.id;
                return (
                  <div
                    key={state.id}
                    id={`state-item-${state.id}`}
                    onClick={() => setSelectedState(state)}
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      padding: "12px 14px",
                      borderRadius: 10,
                      background: isActive ? "var(--bg-active)" : "var(--bg-card)",
                      border: isActive ? "1px solid var(--accent)" : "1px solid var(--border)",
                      cursor: "pointer",
                      transition: "all 0.2s ease",
                    }}
                  >
                    <div>
                      <div style={{ fontWeight: 600, fontSize: 14, color: isActive ? "var(--accent)" : "var(--text-primary)" }}>
                        {lang === "ar" ? state.name_ar : state.name_en}
                      </div>
                      <div style={{ fontSize: 12, color: "var(--text-muted)", marginTop: 2 }}>
                        {lang === "ar" ? state.name_en : state.name_ar}
                      </div>
                    </div>

                    <div style={{ display: "flex", gap: 6 }}>
                      <button
                        id={`edit-state-${state.id}`}
                        className="btn btn-ghost btn-icon btn-sm"
                        onClick={(e) => openEditState(state, e)}
                        title={t("edit")}
                      >
                        <Pencil size={13} />
                      </button>
                      <button
                        id={`delete-state-${state.id}`}
                        className="btn btn-ghost btn-icon btn-sm"
                        style={{ color: "var(--danger)" }}
                        onClick={(e) => handleStateDelete(state.id, e)}
                        title={t("delete")}
                      >
                        <Trash2 size={13} />
                      </button>
                    </div>
                  </div>
                );
              })}

              {filteredStates.length === 0 && (
                <div style={{ textAlign: "center", padding: 30, color: "var(--text-muted)", fontSize: 13 }}>
                  {t("noStatesYet")}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Right Side: Cities Column */}
        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h2 style={{ fontSize: 16, fontWeight: 700, display: "flex", alignItems: "center", gap: 8 }}>
              <Building size={18} className="text-primary" />
              {t("cities")}
              {selectedState && (
                <span className="badge badge-admin" style={{ fontSize: 11, padding: "2px 8px" }}>
                  {lang === "ar" ? selectedState.name_ar : selectedState.name_en}
                </span>
              )}
            </h2>
            {selectedState && (
              <button id="add-city-btn" className="btn btn-primary btn-sm" onClick={openCreateCity}>
                <Plus size={14} /> {t("addCity")}
              </button>
            )}
          </div>

          {!selectedState ? (
            <div style={{
              textAlign: "center",
              padding: "80px 40px",
              color: "var(--text-muted)",
              background: "var(--bg-page)",
              border: "1px dashed var(--border)",
              borderRadius: 12,
              fontSize: 14,
            }}>
              {t("selectState")}
            </div>
          ) : (
            <>
              <input
                className="input btn-sm"
                style={{ marginBottom: 14 }}
                placeholder={t("searchPlaceholder")}
                value={citySearch}
                onChange={e => setCitySearch(e.target.value)}
              />

              {loadingCities ? (
                <div style={{ padding: 40, display: "flex", justifyContent: "center" }}>
                  <div className="spinner" style={{ width: 28, height: 28 }} />
                </div>
              ) : (
                <div style={{
                  display: "flex",
                  flexDirection: "column",
                  gap: 8,
                  maxHeight: "500px",
                  overflowY: "auto",
                }}>
                  {filteredCities.map(city => (
                    <div
                      key={city.id}
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        padding: "12px 14px",
                        borderRadius: 10,
                        background: "var(--bg-card)",
                        border: "1px solid var(--border)",
                      }}
                    >
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 14 }}>
                          {lang === "ar" ? city.name_ar : city.name_en}
                        </div>
                        <div style={{ fontSize: 12, color: "var(--text-muted)", marginTop: 2 }}>
                          {lang === "ar" ? city.name_en : city.name_ar}
                        </div>
                      </div>

                      <div style={{ display: "flex", gap: 6 }}>
                        <button
                          id={`edit-city-${city.id}`}
                          className="btn btn-ghost btn-icon btn-sm"
                          onClick={() => openEditCity(city)}
                          title={t("edit")}
                        >
                          <Pencil size={13} />
                        </button>
                        <button
                          id={`delete-city-${city.id}`}
                          className="btn btn-ghost btn-icon btn-sm"
                          style={{ color: "var(--danger)" }}
                          onClick={() => handleCityDelete(city.id)}
                          title={t("delete")}
                        >
                          <Trash2 size={13} />
                        </button>
                      </div>
                    </div>
                  ))}

                  {filteredCities.length === 0 && (
                    <div style={{ textAlign: "center", padding: 30, color: "var(--text-muted)", fontSize: 13 }}>
                      {t("noCitiesYet")}
                    </div>
                  )}
                </div>
              )}
            </>
          )}
        </div>
      </div>

      {/* State Create/Edit Modal */}
      {showStateModal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setShowStateModal(false)}>
          <div className="modal">
            <div className="modal-title">{editState ? t("editState") : t("addState")}</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div className="form-group">
                <label className="form-label">{t("stateEn")}</label>
                <input
                  id="state-name-en"
                  className="input"
                  value={stateForm.name_en}
                  onChange={e => setStateForm(f => ({ ...f, name_en: e.target.value }))}
                />
              </div>
              <div className="form-group">
                <label className="form-label">{t("stateAr")}</label>
                <input
                  id="state-name-ar"
                  className="input"
                  value={stateForm.name_ar}
                  onChange={e => setStateForm(f => ({ ...f, name_ar: e.target.value }))}
                  dir="rtl"
                />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setShowStateModal(false)}>{t("cancel")}</button>
              <button
                id="save-state-btn"
                className="btn btn-primary"
                onClick={handleStateSubmit}
                disabled={savingState || !stateForm.name_en || !stateForm.name_ar}
              >
                {savingState ? <div className="spinner" /> : editState ? t("saveChanges") : t("add")}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* City Create/Edit Modal */}
      {showCityModal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setShowCityModal(false)}>
          <div className="modal">
            <div className="modal-title">{editCity ? t("editCity") : t("addCity")}</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div className="form-group">
                <label className="form-label">{t("cityEn")}</label>
                <input
                  id="city-name-en"
                  className="input"
                  value={cityForm.name_en}
                  onChange={e => setCityForm(f => ({ ...f, name_en: e.target.value }))}
                />
              </div>
              <div className="form-group">
                <label className="form-label">{t("cityAr")}</label>
                <input
                  id="city-name-ar"
                  className="input"
                  value={cityForm.name_ar}
                  onChange={e => setCityForm(f => ({ ...f, name_ar: e.target.value }))}
                  dir="rtl"
                />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setShowCityModal(false)}>{t("cancel")}</button>
              <button
                id="save-city-btn"
                className="btn btn-primary"
                onClick={handleCitySubmit}
                disabled={savingCity || !cityForm.name_en || !cityForm.name_ar}
              >
                {savingCity ? <div className="spinner" /> : editCity ? t("saveChanges") : t("add")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
